OpsWorks Plone Deployments
==========================

This cookbook provides mechanisms for automating scalable and
high-availability deployments of Plone via buildout in AWS OpsWorks.

It expects a buildout stored in one of the allowed OpsWorks app SCM
repo types (git, http archive, S3 archive), with the following
structure.

  * `bootstrap.py`
  * `cfg/base.cfg`

Where `base.cfg` contains all parts needed for the application
(explicit support provided for `zeoserver`, `solr` and `celery` (by
default backed by redis)), but not enabled.  It expects a zeoclient
named `client1` to be configured in `base.cfg`.  Additionally, it
expects a file named:

  * `cfg/relstorage.cfg`

Which customizes `client1` for relstorage enabled deployments.  There
are examples of these .cfg files provided in `examples/buildout`.  The
recipes below manage all supervisor/upstart/sysvinit jobs, so there's
no need to provide job management in the buildout except in the
development config.

Most of the documentation below describes how to create a
multi-layered stack that offers redundancy and scalability.  With a
complex modular stack you can take advantage of auto-healing of failed
servers and time/load based instances.  If you want a simple single
instance stack that's unlikely to need to grow, and for which small
amounts of downtime are acceptable, skip to the end section
[A Simple Plone Deployment Stack](#a-simple-plone-deployment-stack)
for a simpler stack configuration.


A Scalable Stack Structure
--------------------------

The first step is creating an OpsWorks Stack which includes this set
of cookbooks and provides the desired layers of functionality.

In the OpsWorks console create a stack with `Use Custom Cookbooks`
enabled, the `Repository URL` set to
`git@github.com:alecpm/opsworks-web-python.git` the branch set to
`opsworks-cookbooks`, and an appropriate SSH key.  It's best to choose
Ubuntu LTS as the default OS, and instance store instances.


## Layers

Next you will need to create layers of functionality for the stack.
We'll start with the app itself.


### Plone Instances Layer

Add a layer, choose type `custom` and give it the shortname
`plone_instances` (the default HAProxy config depends on this name to
find the instances).  The default values should be fine for this
layer.  Assign the following custom recipes to the layer:

  *  Setup: `plone_buildout::instances-setup`
  *  Configure: `plone_buildout::instances-configure`
  *  Deploy: `plone_buildout::instances-deploy`
  *  Undeploy: `plone_buildout::instances-undeploy`
  *  Shutdown: `plone_buildout::instances-stop`

You can custom some aspects of the deployment using the
`plone_instances` key in the Stack configuration JSON.  In particular
you may wish to customize the following values:

  * `app_name`: The shortname of the app to be deployed on this layer (defaults to 'plone_instances')
  * `site_id`: The id of the Plone site for VHosting (defaults to 'Plone')
  * `per_cpu`: The number of instances to run per ECU (defaults to 2), alternatively you can set a fixed `instance_count`
  * `nfs_blobs`: Mount shared blobs via NFS
  * `gluster_blobs`: Mount shared blobs via GlusterFS
  * `enable_relstorage`: Use RelStorage for Database
  * `relstorage`: Contains DB connection, and caching related attributes, see `attributes/default.rb`
  * `enable_celery`: Enable the celery buildout part
  * `broker_layer`: The name of the layer where the celery broker server(s) live (defaults to 'redis').
  * `broker`: A hash with `host` and `port` for a fixed celery broker server (i.e. ElastiCache for Redis)
  * `zodb_cache_size`: The size of the zodb object cache
  * `persistent_cache`: Whether to enable to ZEO persistent cache (defaults to true)
  * `zserver_threads`: How many ZServer Threads to use (defaults to 2, setting to 1 makes sense for production use)
  * `sticky_sessions`: Whether the load balancer should use sticky sessions (defaults to false)
  
You'll want to turn one of the two blob mount options on.  More on that below.

These recipes will do all the work of setting up the server, running
the buildout, etc.  However, there will be no DB for it to connect to
and no persistent storage.  We want some more layer(s) for that.


### DB Layer(s)

I recommend two layers for a ZEO server setup.  One providing shared
blobs via NFS or GlusterFS, and one providing the ZEO server itself.
Alternatively, you can use Relstorage (perhaps with Amazon RDS), but
you'll still need the shared blobs layer, so we'll start with that.


#### Shared Blobs Layer

Create a new layer of type `custom` and give it the short name
`shared_blobs` (you can customize the layer shortname and assign this
functionality to an existing layer by setting the
`"plone_blobs": "layer"` attribute to the short name of the desired
layer).  You'll want to use EBS optimized instances here, and
assign an EBS mount to `/srv/exports` for NFS or
`/srv/gluster-exports` for GlusterFS.

Assign the following custom recipes for NFS:

  * Setup: `plone_buildout::nfs_blobs`
  * Configure: `plone_buildout::nfs_blobs`

Or for GlusterFS:

  * Setup: `plone_buildout::gluster`
  * Configure: `plone_buildout::gluster`

##### Notes on using GlusterFS (EXPERIMENTAL)

Use of GlusterFS for shared blobs should be considered eperimental.
Your stack should only start a single GlusterFS shared blob instance
initially, otherwise it is impossible to determine on which instance
the volume configuration should happen leading to unpredictable
results.  You can later add additional instances to the layer for
redundancy and read performance improvements.

If you are using GlusterFS in production, you should ensure the
instances running it have an unchanging Hostname/IP, which means
either using an Elastic IP or a private VPS instance with only a
static private address.  Gluster will not recognize a re-attached
`brick` (in our case EBS volume) unless it's on a host with the same
hostname.

Finally, you will likely want to preserve the volume configuration on
your GlusterFS servers across reboots.  That means that you should
either use EBS backed instances for your GlusterFS servers, or mount a
small EBS volume for holding the GlusterFS configuration across
reboots (mounted at /var/lib/glusterd).  If you ever do accidentally
loose the configuration for your volume, you can remount an existing
brick while preserving data by following the [guidelines
here](http://joejulian.name/blog/glusterfs-path-or-a-prefix-of-it-is-already-part-of-a-volume/).  You should never attempt to add an EBS volume which already
has (potentially out of date) data to an existing GlusterFS volume.
Newly launched replica servers must either retain configuration from
an older server or use a fresh EBS volume.


#### ZEO Server Layer

Create a new layer for a ZEO server and give it the short name
`zeoserver` (you can customize the layer shortname and assign this
functionality to an existing layer by setting the
`"plone_instances": "zeo_layer"` attribute to the short name of the
desired layer).  You'll want to default to an EBS Optimized
instance here, and setup an initial EBS mount on
`/srv/www/zeoserver/shared/var`.

Assign the following custom recipes:

  *  Setup: `plone_buildout::zeoserver-setup`
  *  Configure: `plone_buildout::zeoserver-configure`
  *  Deploy: `plone_buildout::zeoserver-deploy`
  *  Undeploy: plone_buildout::zeoserver-undeploy
  *  Shutdown: plone_buildout::zeoserver-stop

Like the Plone Instances layer, this will use your buildout and
requires an associated app.  There are some custom stack JSON
attributes for this layer that may be of use, under the
`plone_zeoserver` key:

  * `enable_backup`: Defaults to true for daily repozo backups
  * `nfs_blobs`: Enable mounting of shared blobs via NFS
  * `gluster_blobs`: Enable mounting of shared blobs via GlusterFS

You'll want to turn one of the two blob mount options on.


#### RelStorage Layer

No Layer is needed for Relstorage.  Though you could use the built-in
MySQL layer to provide your DB, the instances recipe assumes a
hardcoded DB, and using PostgreSQL RDS is recommended.  If you enable
caching in RelStorage, you can either add a Memcached layer, with the
default settings, or point `"plone_instances": "relstorage":
"cache_servers"` to list of `host:port` pairs for static memcached
server(s) (e.g. ElastiCache for Memcached).


### Front End Layer

OpsWorks has a nice HAProxy layer which detects application instances
(with a little help from this cookbook), but Plone needs a custom
config with multiple services per instance, it's also nice to pair
that up with Varnish and Nginx.  Create an HAProxy layer, set a
reasonable health check url (I use '/misc_/CMFPlone/plone_icon') and
method (`HEAD`).  Enable stats and customize the stats username and
password.  Then add the following custom recipes to get use a custom
config and install/configure Varnish and Nginx:

  * Setup: `plone_buildout::haproxy` `plone_buildout::varnish` `plone_buildout::nginx`
  * Configure: `plone_buildout::haproxy` `plone_buildout::varnish` `plone_buildout::nginx`
  * Deploy: `plone_buildout::haproxy`

This will give you an all-in-one front-end layer with Nginx -> Varnish
-> HAProxy.


### Maintenance Layers


#### EBS Snapshots Layer

Those instances that have EBS volumes will probably want those volumes
snapshotted regularly.  You can assign the following recipe to all
layers that mount EBS volumes:

  * Setup: plone_buildout::ebs_snapshots

Alternatively, if you have multiple layers with EBS mounts, you could
create a new custom layer with only that recipe assignment.  By
default snapshots will be taken daily and 15 will be kept for each
volume.

##### A Custom User with Snapshot Permissions

The snapshotting needs a little extra configuration in the form of a
special AWS user with credentials and permissions to manage snapshots.
Go to the AWS account IAM home page, and select Users.  Then use
`Create New Users` to create a new user (I call her `snapshotter`).
The user needs a permission policy that grants the following
permissions:

  * ec2:CreateSnapshot
  * ec2:CreateTags
  * ec2:DeleteSnapshot
  * ec2:DescribeInstances
  * ec2:DescribeSnapshots

You can just use the following policy:

    {"Version": "2012-10-17",
     "Statement": [
       {"Sid": "Stmt1395696678000",
        "Effect": "Allow",
        "Action": [
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots"
        ],
        "Resource": ["*"]
       }
     ]
    }

The credentials for this new account will need to be added to the
Stack JSON under the key `"ebs_snapshots"` as `"aws_key"` and
`"aws_secret"` (see [A Simple Plone Deployment Stack](#a-simple-plone-deployment-stack)
for an example of Stack JSON that includes these values).


#### RelStorage Packing Layer

You only want one of your instances running RelStorage DB packs, so
it's best to create new layer for that and assign only one of your
application instances at a time to it.  Create a new custom layer and
assign it the following recipes:

  * Configure: `plone_buildout::enable_pack`
  * Deploy: `plone_buildout::enable_pack`

The packing supports a couple options (under the `"plone_instances": "relstorage"` key):

  * `pack_days`: How many days to keep (defaults to 7)
  * `two_stage_pack`: Whether to separate the pack into a pre-pack and pack phases over two days.

This recipe assumes the presence of `zodbpack`, `zodbpack-prepack`,
and `zodbpack-pack` builsout parts in `cfg/base.cfg`.  Those parts
determine pack frequency/time, and default to weekly.


### Extra Layers

Some applicatons may wish to install additional layers of
functionality, like a Solr Search engine or a Redis queue server.


#### Solr Layer

To ease Solr configuration, we deploy Solr through the buildout (see
`example/buildout`) using `collective.recipe.solrinstance`.  This
means adding another custom layer, with short name `solr` (you can
customize the layer shortname or assign this functionality to an
existing layer by setting the `"plone_instances": "solr_layer"`
attribute to the short name of the desired layer).  Because it needs a
persistent data store, it should default to EBS Optimized with an EBS
volume mounted at `/srv/www/solr/shared/var`.  Assign the following
custom recipes:

  *  Setup: `plone_buildout::solr-setup`
  *  Configure: `plone_buildout::solr-configure`
  *  Deploy: `plone_buildout::solr-deploy`
  *  Undeploy: `plone_buildout::solr-undeploy`
  *  Shutdown: `plone_buildout::solr-stop`

All solr configuration should be done in the buildout configs.

#### Redis Layer

If you want to install Redis on an new/existing layer add the
following custom recipe:

  * Setup: redis::default 

You may wish to mount an EBS to store redis data persistently, but ne
necessity of doing so probably depends on your specific application.


## Applications

Now you need to point your application layers at actual applications
(i.e. your buildout).  Fortunately, that's the easy part.

### Plone Instances Application

Add a new application with type `Other` and short name
'plone_instances' (or whatever you set `"plone_instances": "app_name"`
to in the Stack JSON).  Set the repository type, url and credentials.
It's important to note that the key entered here will be used by any
submodule or mr.developer requests, so it must provide access to all
repos relevant to the application.

You may provide application specific configuration via the Stack JSON.
Under the `"deploy": app_name` key.  Properties you may wish to set
include:

  * `os_packages`: Any required packages to be installed via apt
  * `buildout_extends`: An array of additional extends files to use (e.g. `["cfg/sources.cfg"]`)
  * `buildout_parts_to_include`: An array of additional parts to include (e.g. `["celery"]`)
  * `buildout_init_commands`: An array of additional (non-instance) commands for supervisor to control (e.g. `[{"name": "celeryd", "cmd": "bin/celeryd", "args": "console"}]`)
  * `environment`: A mapping of environment variables to include in the buildout
  * `buildout_cache_archives`: An array with tgz archives to be fetched and expanded at a specific path (e.g. a cache of eggs or downloads, to speedup the initial build).  Example: `[{"url" : "https://url.to/plone-5.0-eggs.tgz", "path" : "shared/eggs", "user": "me", "password": "secret"}]`
  * `always_build_on_deploy`: Always run buildout on a deploy action, even if neither the buildout repo nor the config file changed.  This is necessary if you use mr.developer in your buildout in order to pull in code changes in the deploy step.

See documentation for opsworks_deploy_python documentation for more
info on specific deploy options available.

### Zeoserver Application

Same as above but give your application the short name `zeoserver`.

### Solr Application

Same as above but give your application the short name `solr` (or
whatever you set `"plone_solr": "app_name"` to in the Stack JSON).


## Running Instances

You have now defined a stack describing all the layers of
functionality, from front end, to caches, to application servers, to
backend storage.  Now you need to actually add some instances.  You
may add an instance to any of the layers.  Once you've added it,
before starting it, you can assign additonal layers.  Some layers
should only have a single instance (Shared Blobs if using NFS, ZEO
Server, Solr, Redis), generally they are the ones with persistent
storage requirements.  Others can support multiple instances (the
Plone instances, the HAProxy front end), GlusterFS shared blobs which
replicate the storage across each new instance).

The Resources tab lets you assign existing resources (e.g. Elastic
IPs, EBS volumes or snapshots) to stopped instances.  When you start
an instance all of the functionality of the assigned layers will be
incorporated, all assigned resources will be attached, and all
resources expected by the layers which are not yet attached will be
created.

Whenever a new instance is started and comes online, the Configure
event is triggered for all instances/Layers in the Stack.  This allows
things like HAProxy to detect new instances, the Gluster server to add
new replica volumes, etc.  By default the buildout based layers will
not be re-built or restarted on configure events, though it's possible
to force this behavior if desired (see above).


## Deployments

Apps are deployed to their respective layers (as determined by the
custom recipe `app_name` parameters) automatically after instance
start.  Apps can be re-deployed from the App page.  A Deploy causes
code to be updated from the App SCM repository, the configuration
updated based on current stack configuration, buildout re-run and
services restarted.

The Deploy page also offers other commands (e.g. Stop, Start,
Restart). Unfortunately, those do not work with custom application
layers.  To manually restart instances, you can use the `Run Command`
button on the stack page to run a custom recipe.  For example
`plone_buildout::instances-restart` or `plone_buildout::solr-stop`.


## Helper Recipes

This cookbook also includes a couple simple helper recipes:

  * varnish-restart: Restarts varnish
  * varnish-purge: Runs a "ban.url" for a array of url regexps provided (defaults to all content in the cache).  Provide the array in the `node["varnish_purge_urls"]` attribute.


## Motivation

After reading this, it may seem complicated to setup a stack of this
sort, and it may be overkill for some uses.  It's ideal for
environments which need multi-server production clusters, but also
want to have identical single-server staging and development
environments.

Using this multi-Layered technique, it's possible to have a staging
Stack that's cloned from a complex production Stack, all Layers
running on a single instance.  You can use environment variables (set
in the `"deploy": app_name` namepace) and DB connection settings in
the Stack JSON to differentiate between the environments.

For example, it's possible to have a production stack that has
multiple Front Ends, Memcaches, Plone Instance servers, and GlusterFS
Shared Blob replicas running in different Availability Zones within a
region.  An Elastic Load Balancer can be used to balance the traffic
across the multiple front ends.  With RelStorage on RDS, you can use
Multi-AZ deployments to have automated failover of the database to a
second AZ.  Redis can be made redundant using ElastiCache, if needed.
This configuration can allow elimination of nearly all SPF (Solr is
generally an exception if enabled).

Additionally, OpsWorks has built-in time and Load based auto-scaling
allow you to automatically spin up new instances or other services as
needed based on a fixed schedule or on server load.  This layered
configuration allows you to easily scale up just those parts of your
deployment which need it (generally the plone instances).


A Simple Plone Deployment Stack
-------------------------------

If you really don't need any of that fancy redundancy or scalability,
you can make a simple single layer stack.

Create a [Front End Layer](#front-end-layer), as described above and
assign it the custom recipes for that layer as documented above.
Also, assign it the custom recipes from [Plone Instances Layer](#plone-instances-layer)
and those from the [EBS Snapshots Layer](#ebs-snapshots-layer).
Set the layer to use EBS Optimized instances (you will only
ever be using one instance), and assign two EBS volumes at
'/srv/www/plone_instances/shared/var/blobstorage' and
'/srv/www/plone_instances/shared/var/filestorage'.

You can mount additional EBS volumes for repozo backups if you want
those to persist across server failures and instance stop/starts
(though for catastrophic failures EBS snapshots are probably a better
choice than repozo backups for getting up and running quickly).  You
can add EBS mounts for any additional buildout parts you may want to
include which require persistent storage (e.g. `.../shared/var/solr`).
In theory, you could mount the entire `.../shared/var` as a single EBS
volume, but EBS is much slower than instance storage and is probably
not an ideal place for storing logs, tmp files and other ephemera.

Create an App pointing at your repository as described in [Plone
Instances Application](#plone-instances-application).

Configure your stack json as follows:

    {"opsworks" : { "ruby_stack" : "ruby", "ruby_version" : "1.9.3" },
       "deploy" : {
         "plone_instances" : "buildout_parts_to_include": ["zeoserver", ...],
         "buildout_extends" : ["cfg/sources.cfg", ...],
         "buildout_init_commands" : [{"name" : "zeoserver", "cmd" : "bin/zeoserver", "args" : "console"}],
         "environment" : {"SOME_VARIABLE" : "SOME VALUE"},
       },
       "ebs_snapshots" : {
         "aws_key" : "***** AWS KEY FOR SNAPSHOTTING (IAM USER) *****",
         "aws_secret" : "***** AWS SECRET FOR SNAPSHOTTING (IAM USER) *****"
       }
    }

See [A Custom User with Snapshot Permissions](#a-custom-user-with-snapshot-permissions)
above for info about setting up IAM user credentials for taking EBS
snapshots.

Notice that it's possible to manually include whatever buildout parts
and extends values you want in the deploy JSON.  You can also add any
commands you wish to the supervisor init (in this case we add our
zeoserver).  The recipe will still generate a number of `client#{n}`
parts based on the instance size and launch them via the system
supervisor.

That's all that's needed for a single layer deployment; however,
breaking each bit of functionality (App Servers, DB Servers/Blob
Storage, Front End) into its own layer can offer significant
advantages in exchange for a little extra up-front effort.


## More information

* [A gentle introduction to OpsWorks](http://artsy.github.io/blog/2013/08/27/introduction-to-aws-opsworks/)

* [Official OpsWorks documentation](http://docs.aws.amazon.com/opsworks/latest/userguide/welcome.html)

* [CLI Opsworks](http://docs.aws.amazon.com/cli/latest/reference/opsworks/index.html)

* Some AWS CLI tool JSON exports of an example stack are in `examples/`.  Look in the `examples/example-custom-json.json` for a Stack JSON example which includes an egg cache download.


## To Do

* Enable automated copying/pruning of EBS snapshots across regions, to allow
quick recovery from region wide outages.

* Allow egg cache archives to be stored in private s3 buckets.

* Better management of the comings and goings of GlusterFS peers.

* Alternatives for blob storage.  (S3, Ceph?)

* Boto based scripts to perform initial complex Stack setup interactively (?)


## License && Authors
* Alec Mitchell <alecpm@gmail.com>

With thanks to Jazkarta, Inc. and KCRW Radio
```text
Copyright 2014, Alec Mitchell

Licensed under the BSD License.
```
