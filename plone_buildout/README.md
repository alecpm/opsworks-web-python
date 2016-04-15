OpsWorks Plone Deployments
==========================

This cookbook provides mechanisms for automating scalable and
highly-availabile deployments of Plone via buildout in AWS OpsWorks.

It expects a buildout stored in one of the allowed OpsWorks app SCM
repo types (git, SVN, http archive, S3 archive), with a certain
structure and naming convention for parts.  An example buildout is
available in the [opsworks_example_buildouts GitHub
repo](http://github.com/alecpm/opsworks_example_buildouts).  This
example buildout is intended to be used as a base for new projects
which are intended to be deployed in a modular manner (with services
potentially running across multiple machines).


Quick Start
-----------

The `plone_buildout` cookbook contains a couple CloudFormation
templates for automating the build of multi-layered Zeo and Relstorage
Stack deployments.  To use these to setup an Opsworks stack, login to
your AWS account and navigate to the [CloudFormation
Dashboard](https://console.aws.amazon.com/cloudformation/home).  There
you can select Create New Stack (note that a CloudFormation stack is
not the same as on OpsWorks stack, but in this case you will be using
the latter as a mechanism to create the former).

You should give your stack a name, and then choose Upload Template.
The templates live in ``examples/zeoserver-stack.template`` and
``examples/relstorage-stack.template``, choose one of those.  You
won't need to enter any stack Options/Tags, so click `Next` and then
`Create`.  Once the create process has completed, you'll have a new
OpsWorks stack in the OpsWorks console.

You will Need to add your stack specific JSON and enable `Manage
Berkshelf` to pull in cookbook dependencies.  Go to `Stack Settings`
-> `Edit` to set these.  For a Zeo deployment with NFS shared blobs,
the simplest Custom JSON is the following:

    {
      "plone_instances" : {
        "app_name" : "plone_instances", "nfs_blobs" : true
      },
      "zeoserver" : {
        "nfs_blobs" : true
      },
      "deploy" : {
        "plone_instances" : {},
        "zeoserver" : {}
      }
    }

For a relstorage stack assign a Postgresql Database to the app, and use the
following Custom JSON:

    {
      "plone_instances" : {
        "app_name" : "plone_instances",
        "nfs_blobs" : true,
        "enable_relstorage": true
      },
      "deploy" : {"plone_instances" : {}}
    }

To store blobs in your Relstorage DB:

    {
      "plone_instances" : {
        "app_name" : "plone_instances",
        "shared_blobs": false,
        "enable_relstorage": true
      },
      "deploy" : {"plone_instances" : {}}
    }


Additionally, you may also want to enable EBS Optimized instances for any
layers which have mounted EBS volumes (Shared Blobs, Zeoserver, ...).  You can
do this by editing the EBS Volumes tab of the desired layer.

Finally, if you intend to use separate servers for various services, you will
want to update the security groups for layers which provide internal services
within the layers.  The easiest way to do this is to add the `default`
security group (for your region or current VPC) to the security groups for
those layers (generally the HAProxy/LB, Shared Blobs, Solr, and Plone
Instances layers).  Alternatively, you can create custom security groups to
limit connectivity to the specific ports required by those services.

It is recommended that RelStorage based stacks use Amazon RDS with Multi-AZ to
provide high avaialability.  If you create and RDS to server your database ,
be sure that its security group allows access to the `AWS-OpsWorks-Custom-
Server` EC2 Security Group that your zope instances will run under (or add the
`default` security group for the `Plone Instances` layer as above and either
add the RDS to that security group or modify the RDS security group to allow
access from the `default` group).

You'll generally want to update the Stack's Apps to set the application
repository parameters to your buildout (see [Applications](#applications)).
Then you'll want to configure and start some instances (see
[Instances](#instances)).  Initially, you'll probably want to start by adding
all layers to a single instance, but you can have multiple instances per layer
and multiple layers per instance in whatever configuration makes sense for
your application.

The layers automatically created by CloudFormation can be customized
extensively, and details are provided below regarding the functionality and
configuration of each layer.


Under the Hood of a Scalable Stack Structure
--------------------------------------------

The Quick Start will automatically create a number of layers for you.
However, it's important to understand how those layers work, how you
can customize them and how to add additional layers which you might
need.  The default stacks for Plone involve a large number of layers,
which may at first seem unnecessary.  However, with a complex modular
stack you can easily scale horizontally, and create high availablity
deployments.  You can even take advantage of auto-healing of failed
servers and time/load based instances.  If you want a simple single
instance stack that's unlikely to need to grow, and for which some
downtime is acceptable, skip to the end section [A Simple Plone
Deployment Stack](#a-simple-plone-deployment-stack) for a simple
non-scalable stack configuration.


## The Essential Layers


### Plone Instances Layer

This is a custom application server layer named `plone_instances` by default.
It includes the following recipes:

  *  Setup: `plone_buildout::instances-setup`
  *  Configure: `plone_buildout::instances-configure`
  *  Deploy: `plone_buildout::instances-deploy`
  *  Undeploy: `plone_buildout::instances-undeploy`
  *  Shutdown: `plone_buildout::instances-stop`

This layer needs an associated App (essentially a buildout repository configuration).

You can customize many aspects of the deployment using the
`plone_instances` key in the Stack configuration JSON.  In particular
you may wish to customize the following values:

  * `app_name`: The shortname of the app to be deployed on this layer (defaults to 'plone_instances')
  * `site_id`: The id of the Plone site for VHosting (defaults to 'Plone')
  * `per_cpu`: The number of instances to run per ECU (defaults to 2), alternatively you can set a fixed `instance_count`
  * `nfs_blobs`: Mount shared blobs via NFS
  * `gluster_blobs`: Mount shared blobs via GlusterFS (mutually exclusive with the above parameter)
  * `enable_relstorage`: Use RelStorage for the Zope database
  * `relstorage`: Contains DB connection, and caching related attributes, see `attributes/default.rb`
  * `enable_celery`: Enable the celery buildout part
  * `celerybeat`: Enable a celerybeat worker (defaults to false, should be applied in a layer in a multi-server config to avoid duplicate schedulers)
  * `broker_layer`: The name of the layer where the celery broker server(s) live (defaults to 'celery_broker').
  * `broker`: A hash with `host` and `port` for a fixed celery broker server (i.e. for use with ElastiCache for Redis)
  * `zodb_cache_size`: The size of the zodb object cache
  * `persistent_cache`: Whether to enable to ZEO persistent cache (defaults to true)
  * `zserver_threads`: How many ZServer Threads to use (defaults to 2, setting to 1 may make sense for production use)
  * `sticky_sessions`: Whether the load balancer should use sticky sessions (defaults to false)
  * `solr_enabled`: Whether to enable Solr search using `alm.solrindex` (defaults to false)
  * `solr_layer`: Name of layer in which to find Solr servers
  * `solr_host`: Host name for a fixed solr server (not needed if you have a solr layer)
  * `restart_delay`: Delay in seconds between starting/restarting each instance, used for rolling restarts.
  
You'll probably want to turn one of the two blob mount options on.  The default stack configuration sets up an NFS lauyer for shared blobs.  More on that below.

These recipes will do all the work of setting up the server, running
the buildout, etc.


### DB Layer(s)

I recommend two layers for a ZEO server setup.  One providing shared
blobs via NFS or GlusterFS, and one providing the ZEO server itself.
Alternatively, if you have a single instance you can just have a
shared `blob_dir` on the instance.


#### Shared Blobs Layer

This is another layer of type `custom` with the short name
`shared_blobs` (you can customize the layer shortname and assign this
functionality to an existing layer by setting the `"plone_blobs":
"layer"` attribute in the Stack Custom JSON to the layer short).
You'll probably want to use EBS optimized instances here, and assign
an EBS mount to `/srv/exports` for NFS or `/mnt/gluster-exports` for
GlusterFS.

The layer uses NFS by default and runs the following recipes:

  * Setup: `plone_buildout::nfs_blobs`
  * Configure: `plone_buildout::nfs_blobs`

For GlusterFS it would need to be modified to run the following recipes instead:

  * Setup: `plone_buildout::gluster`
  * Configure: `plone_buildout::gluster`

There are a number of configuration options for the shared blob
storage under the `plone_blobs` key.  See `attributes/defaults.rb` for
details.  If you would like to simply use a shared blob dir on a
single instance, you may remove this layer, and set the "plone_blobs":
"blob_dir" attribute to the desired location (generally
`/mnt/shared/blobstorage`).

##### Notes on using GlusterFS (EXPERIMENTAL)

Use of GlusterFS for shared blobs should be considered eperimental.
Your stack should only start a single GlusterFS shared blob instance
initially, otherwise it is impossible to determine on which instance
the volume configuration should be primary leading to unpredictable
results.  You can later add additional instances to the layer for
redundancy and read performance improvements.

If you are using GlusterFS in production, you would ideally have
instances with a static private IP, which means using a private VPS
instances.  Gluster will not recognize a re-attached `brick` (in our
case EBS volume) unless it's on a host with the same hostname or IP.

If you have instances which retain their priavte IP between restarts,
you will want to retain the GlusterFS configuration across instance
termination.  You can do this using EBS backed instances, or by storing
configuration on the same EBS volume used for the FS exports by
setting "plone_blobs": "gluster_store_config_in_exports" to `true`.

If you do accidentally loose the configuration for your volume,
you can remount an existing brick while preserving data by following
the [guidelines
here](http://joejulian.name/blog/glusterfs-path-or-a-prefix-of-it-is-already-part-of-a-volume/), more on this below.

Stopping and starting a Gluster peer without a fixed internal IP will
generally require some manual intervention to reconnect the brick to
the cluster.  You should always try to keep one Gluster peer online.
The following steps should work to re-incoporate a restarted instance
into the volume:

  * On the working peer (IP0), find any disconnected peer IPs (IPN):
  (`gluster peer status`)
  * On the newly restarted peer (IP1)
    * Detach peer "gluster peer detach IP0 force"
    * Shutdown gluster: "service glusterfs-server stop"
    * Install the `attr` package (`aptitude install attr`)
    * In the export mount ( `/srv/gluster-exports` by default) run the following
    commands to force gluster to treat the brick as new:

        setfattr -x trusted.glusterfs.volume-id brick
        setfattr -x trusted.gfid brick
        rm -rf brick/.glusterfs

    * Start gluster: `service glusterfs-server stop`
    * Connect to peer: `gluster peer probe IP0`
    * Initiate brick replacement: `gluster volume replace-brick VOLNAME IPN:BRICKPATH IP0:BRICKPATH start` (BRICKPATH is typically `/srv/gluster-exports/brick`)
    * Monitor status: `watch gluster volume replace-brick VOLNAME IPN:BRICKPATH IP0:BRICKPATH status`
    * When complete, commit: `gluster volume replace-brick VOLNAME IPN:BRICKPATH IP0:BRICKPATH status commit`

If you ever loose you primary Gluster configuration, you can re-create the volume manually by using the following steps:

  * Install the `attr` package (`aptitude install attr`)
  * In the export mount (`/srv/gluster-exports` by default) run the following
  commands to force gluster to treat the brick as new:

      setfattr -x trusted.glusterfs.volume-id brick
      setfattr -x trusted.gfid brick
      rm -rf brick/.glusterfs

  * Create the new volume (`gluster volume create blobs IP0:BRICKPATH`)
  * Enable it (`gluster volume start blobs`)
  * Verify (`gluster volume status blobs detail`)

You should generally aim to have three or fewer replicated GlusterFS
blob servers.  Two (each in a different AZ) is probably ideal for
reduncancy.  It may make sense to have a primary peer with an EBS
mounted export volume (with frequent snapshots), and additional
replica peers which use the local (ephemeral) instance store (SSD on
current generation instances), to speed replication and reads for
those servers which connect to that peer.


#### Notes on using S3 for blob storage (s3fs-fuse)

You can store blobs in S3 using a mounting a bucket as a user-space filesystem
and using that for shared blob storage or as the backing store for a ZEO
server serving blobs.  To do so you just need to include the `s3fs-fuse`
recipe early in the `setup` stage of the layers you want to attach the storage
to (either instances and/or zeoserver).  The configuration would look like the
following for shared blobs:

    {
      "s3fs_fuse": {
        "s3_key": YOUR_AWS_KEY_FOR_S3,
        "s3_secret": YOUR_AWS_SECRET_FOR_S3,
        "mounts": [{"bucket: YOUR_BUCKET_NAME,
                    "path": "/mnt/shared/zodb/blobs",
                    "tmp_store": "/mnt/tmp/s3_cache"}]
      },
      "plone_blobs": {"blob_dir": "/mnt/shared/zodb/blobs"}
    }

See the "s3fs-fuse cookbook"[https://github.com/hw-cookbooks/s3fs-fuse]
documentation for more details on parameters.  Using S3 this way will not tend
to provide great performance, though it provides an easy to setup fault-
tolerant network filesystem, which is hard to come by.  Caching (via the ZEO
server) may help alleviate performance issues.


#### ZEO Server Layer

The ZEO server layer is a custom application server layer named
`zeoserver` (you can customize the layer shortname and assign this
functionality to an existing layer by setting the `"plone_instances":
"zeo_layer"` attribute in the Stack Custom JSON to the layer short
name).  You'll probably want to use an EBS Optimized instance here,
and setup an initial EBS mount on `/mnt/shared/filestorage`.

This layer is assigned the following recipes:

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
MySQL layer to provide your DB, using PostgreSQL RDS is recommended.
You may enable caching in RelStorage, either add an OpsWorks Memcached
layer with the default settings, or point `"plone_instances":
"relstorage": "cache_servers"` to a set of static `host:port` pairs
for existing memcached server(s) (e.g. ElastiCache for Memcached).


### Front End Layer

This layer is built on OpsWorks built-in HAProxy layer which detects
application instances (with a little extra help from this cookbook),
but Plone needs a custom config with multiple services per instance,
it's also nice to pair the load-balancer up with Varnish and Nginx.
You'll probably want to customize the stats username and password.

The front end layer uses the following recipes:

  * Setup: `plone_buildout::haproxy` `plone_buildout::varnish`
  `plone_buildout::nginx`
  * Configure: `plone_buildout::haproxy` `plone_buildout::varnish` `plone_buildout::nginx`
  * Deploy: `plone_buildout::haproxy`

It provides an all-in-one front-end layer with Nginx -> Varnish
-> HAProxy.

Note: The built-in HAProxy layer uses an Elastic IP, which is
desirable if you intend to use a single front-end server to serve
your website.  If you want a high-availability deployment with
front-ends in multiple AZs, then you may wish to create your own
custom layer without an Elastic IP to run HAProxy + Varnish + Nginx,
and use an Elastic Load Balancer to balance between the servers in
this layer.


### Maintenance Layers


#### EBS Snapshots Layer

Those instances that have EBS volumes will probably want those volumes
snapshotted regularly.  This layer takes care of that automatically,
by providing nightly snapshots and automatic pruning.  It should be
included on any instances that have mounted EBS volumes.

It consists of the following recipe:

  * Setup: plone_buildout::ebs_snapshots

By default snapshots will be taken daily and 15 will be kept for each
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

You only want one of your instances running RelStorage DB packs.  This
is a layer that should be applied to just one of your plone_instances
instances, in order to ensure that it runs DB packing.

It runs the following recipes:

  * Configure: `plone_buildout::enable_pack`
  * Deploy: `plone_buildout::enable_pack`

The packing supports a couple options (under the `"plone_instances": "relstorage"` key):

  * `pack_days`: How many days to keep (defaults to 7)
  * `two_stage_pack`: Whether to separate the pack into a pre-pack and pack phases over two days.

This recipe assumes the presence of `zodbpack`, `zodbpack-prepack`,
and `zodbpack-pack` builsout parts in the base buildout config.  Those parts
determine pack frequency/time, and default to weekly.


### Additional Layers

You may wish to create additional layers of functionality for your
particular application.  Below are a couple of optional layers that
you can create based on recipes in this cookbook.


#### Solr Layer

To ease Solr configuration, you can deploy Solr through a buildout
using `alm.solrindex` and `collective.recipe.solrinstance`.  This
means adding another custom layer, with short name `solr` (you can
customize the layer shortname or assign this functionality to an
existing layer by setting the `"plone_instances": "solr_layer"`
attribute in the Stack Custom JSON to the layer short name), as well
as another App (named `solr` by default) with the repository
information for the buildout.  Because it needs a persistent data
store, it should use EBS Optimized instances with an EBS volume
mounted at `/mnt/shared/solr`.

It should have the following recipes assigned:

  *  Setup: `plone_buildout::solr-setup`
  *  Configure: `plone_buildout::solr-configure`
  *  Deploy: `plone_buildout::solr-deploy`
  *  Undeploy: `plone_buildout::solr-undeploy`
  *  Shutdown: `plone_buildout::solr-stop`

#### Redis Layer

If you want to install Redis on a new or existing layer add the
following custom recipe:

  * Setup: redis::default 

You may wish to mount an EBS to store redis data persistently, but the
necessity of doing so depends on your specific application.
Alternatively, you can use AWS Redis ElastiCache service to provide a
scalable Redis deployment and set the broker host/port manually in the
Custom JSON for the stack.

#### Celerybeat Layer

If you have enabled `celery` on your plone instances and want to have
one of your instances run a celerybeat scheduler, create a layer with
the following recipes:

  * Configure: `plone_buildout::instances-celerybeat`
  * Deploy: `plone_buildout::instances-celerybeat`

Applying that layer to a single plone_instances application server
instance will ensure that the celerybeat worker runs on only that
instance.

## Applications

Now you need to point your application layers at actual applications
(i.e. your buildout).  Fortunately, that's the easy part.

### Plone Instances Application

The primary application is of type `Other` and short name
'plone_instances' (or the name specified under `"plone_instances":
"app_name"` to in the Stack Custom JSON).  This is where you can set
the repository type, url and credentials.  It's important to note that
the SSH key entered here will be used by any submodule or mr.developer
requests, so it must provide access to all repositories required for
the application.  Github does not allow a single "deploy key" to be
used for multiple repositories, so I recommend creating a new GitHub
user with read-only access to all required repositories and providing
an SSH key for that user.

You may provide application specific configuration via the stack Custom JSON.
Under the `"deploy": app_name` key.  Properties you may wish to set
include:

  * `os_packages`: Any required packages to be installed via apt
  * `buildout_extends`: An array of additional extends files to use (e.g. `["cfg/sources.cfg"]`)
  * `buildout_parts_to_include`: An array of additional parts to include (e.g. `["mycustompart"]`)
  * `buildout_init_commands`: An array of additional (non-instance) commands for supervisor to control (e.g. `[{"name": "mydaemon", "cmd": "bin/mydaemon", "args": "console"}]`).  To use supervisor event listeners like Superlance's `memmon` (you'll need to add a zc.recipe.egg:scripts part to your buildout to build the console scripts in that case), use the `eventlistener` key. (e.g., `[{ "name": "memmon", "init_type": "supervisor", "cmd":  "bin/memmon", "args": "-a 1GB -m foo@baz.com --name='Production memmon'", "eventlistener": true, "eventlistener_events": ["TICK_60"]}]`)
  * `environment`: A mapping of environment variables to include in the buildout and supervisor
  * `buildout_cache_archives`: An array with tgz archives to be fetched and expanded at a specific path (e.g. a cache of eggs or downloads, to speedup the initial build).  Example: `[{"url" : "https://url.to/plone-5.0-eggs.tgz", "path" : "shared/eggs", "user": "me", "password": "secret"}]`
  * `always_build_on_deploy`: Always run buildout on a deploy action, even if neither the buildout repo nor the config file has changed.  This is necessary to update packages when  you use mr.developer in your buildout.  Otherwise the deploy will not re-run the buildout unless the buildout repository has changed.
  * `symlink_before_migrate`: A mapping of directories to link from the shared directory to the buildout directory in the deployment so their contents persist across deployments.  If you use `mr.developer` to manage everything in `src` you'll probably want to use `{"src" : "src"}`.
  * `purge_before_symlink`: An array of directories in the buildout to remove before creating symlinks to shared.  For `mr.developer` based buildouts, you'll want `['src']`.
  * `create_dirs_before_symlink`: An array of directories in the shared directory to create before symlinking.  For `mr.developer` based buildouts, you'll also want `['src']`.

See documentation for opsworks_deploy_python documentation for more
info on specific deploy options available to the buildout and python
deployment recipes.

Using an egg cache archive is highly recommended, it can significantly
improve instance build time.  It's possible to build one instance with
no cache and then tar up the resulting egg dir
(`/srv/www/plone_instances/shared/eggs/`) and upload it to a public s3
bucket or some other web accessible (possibly HTTP AUTH protected)
location.

### Zeoserver Application

Same as above but with the short name `zeoserver` (or the name
specified under `"plone_zeoserver": "app_name"` in the Stack Custom
JSON).  You will generally want to set the same Custom JSON
configuration for this layer as for the instances layer, to ensure the
zeoserver has access to the same os/python packages and settings.

### Solr Application

Same as above but with the short name `solr` (or the name specified
under `"plone_solr": "app_name"` to in the Custom JSON for the stack).
You will not generally need to provide any Custom JSON configuraiton
for this application.


## Running Instances

You have now defined a stack describing all the layers of
functionality, from front end, to caches, to application servers, to
backend storage.  Now you need to actually add some instances.  You
may add an instance to any of the layers.  Once you've added it,
before starting it, you can assign additonal layers.  Some layers
should only have a single instance (Shared Blobs if using NFS, ZEO
Server, Solr, Redis), generally they are the ones with persistent
storage requirements.  Others can support multiple instances (the
Plone instances, the HAProxy front end, GlusterFS shared blobs which
replicate the storage across each new instance).

The Resources tab lets you assign existing resources (e.g. Elastic
IPs, EBS volumes or snapshots) to stopped instances.  When you start
an instance all of the functionality of the assigned layers will be
incorporated, all assigned resources will be attached, and all
resources expected by the assigned layers which are not yet attached
will be created.

Whenever a new instance is started and comes online, the Configure
event is triggered for all instances/Layers in the Stack.  This allows
things like HAProxy to detect new instances, the Gluster server to add
new replica volumes, etc.  By default the buildout based layers will
not be re-built or restarted on configure events (unless the event
causes the buildout config to change, e.g. adding or replacing a
memcached, zeo, solr or celery broker server).


## Deployments

Apps are deployed to their respective layers (as determined by the
custom `app_name` parameters used by each application server recipe)
automatically after instance start.  Apps can be re-deployed from the
App or Deployments sections.  A Deploy causes code to be updated from
the App SCM repository, the configuration updated based on current
stack configuration, buildout re-run and services restarted.

The Deploy page also offers other commands (e.g. Stop, Start,
Restart). Unfortunately, those do not work with custom application
layers.  To manually restart instances, you can use the `Run Command`
button on the stack page to run a custom recipe.  For example
`plone_buildout::instances-restart` or `plone_buildout::solr-stop`.


## Helper Recipes

This cookbook also includes a couple simple helper recipes:

  * varnish-restart: Restarts varnish
  * varnish-purge: Runs a "ban.url" for a array of url regexps provided (defaults to all content in the cache).  Provide the array in the `node["varnish_purge_urls"]` attribute.
  * instances-rebuild: Re-runs buildout on all plone_instances layers, restarts instances.
  * instances-develop-up: Re-runs `bin/develop up` on all plone_instances layers, does not restart instances.  Useful for quick deployment of resource/template changes when developing.


## Server/Application Monitoring

OpsWorks provides a nice panel with graphs of server utilization, and
CloudWatch provides configurable alerting.  However, there are a few essential
things that can't be easily monitored via CloudWatch, including disk space
remaining and HTTP service checking.  Fortunately there are 3rd party services
which offer a combination of server and application monitoring.  This cookbook
includes a few optional monitoring service integrations.


### New Relic

[New Relic](http://newrelic.com) offers full stack server amd application
monitoring, including application performance profiling.  For each layer on
which you wish to implement monitoring, add the `plone_buildout::newrelic`
recipe to the setup action. The newrelic recipe has support for monitoring the
Plone application (using `collective.newrelic`), Nginx, HAProxy, Varnish,
Memcached and Redis.  It is based on the [newrelic
cookbook](https://github.com /escapestudios-cookbooks/newrelic) and supports
the configuration options from that cookbook.  The following settings are the
most essential:

  * `newrelic["license"]`: Your New Relic license key (sign up for a free
account at http://newrelic.com/aws)
  * `plone_instances["newrelic_tracing"]`: Boolean to enable New Relic
application monitoring for Plone
  * `plone_instances["tracing_clients"]`: How many Zeo clients to enable
monitoring on (0 for all)
  * `new_relic["application_monitoring"]["browser_monitoring"]["auto_instrument"]`: Boolean
to enable template transform to inject client side monitoring code

I recommend pulling in the chameleon-support branch of collective.newrelic
into your buildout to get the most up to date Plone New Relic integration.


### Papertrail

[Papertrail](http://papertrailapp.com) is a syslog service which provides
centralized monitoring and searching of server logs.  The recipe currently
supports sending all syslog logs, including HAProxy, Zeoserver and Zeo
clients, as well as additional support for supervisor, solr, nginx (errors)
and redis logs. For each layer on which you wish to implement Papertrail
monitoring, add the `plone_buildout::papertrail` recipe to the setup action.
It is is based on the [papertrail-cookbook](https://github.com/librato/papertrail-cookbook)
and supports te configuration options from that cookbook.  The essential
settings are:

  * `papertrail["remote_host"]`: Remote log host provided by Papertrail
  * `papertrail["remote_port"`: Remote log port provided by Papertrail
  * `plone_instances["syslog_level"]`: Log level to include (e.g. INFO) for
instance logs
  * `plone_zeoserver["syslog_level"]`: Log level to include (e.g. INFO) for
zeoserver logs


### Traceview

[AppNeta Traceview](http://www.appneta.com/products/traceview/) is a service
which provides detailed application profiling of Plone using the
`collective.traceview` addon.  This functionality is somewhat redundant with New
Relic tracing support, but can provide python profiles with a bit more detail.
To enable traceview tracing add the `plone_buildout::traceview` recipe to the
setup action for your Plone Instance layer.  It is based on the [tracelytics-chef
cookbook](https://github.com/Optaros/tracelytics-chef) and supports the
configuration defined in that recipe.  The most essential settings are:

  * `traceview["access_key"]`: Your Traceview account access key
  * `plone_instances["traceview_tracing"]`: Boolean to enable traceview tracing for
Plone
  * `plone_instances["tracing_clients"]`: How many Zeo clients to enable
monitoring on (0 for all)
  * `plone_instances["traceview_sample_rate"]`: What percentage of requests to
profile (1.0 is all requests)

Traceview support is experimental and not recommended for use in production.
Specifically, the deb package installed automatically modifies the nginx
config in a manner that can break responses containing HTML fragments.


### Additional configuration

There is a known issue with volume mounting on r3.large and r3.extralarge
instances.  These cookbooks include a workaround recipe that should be added
to the `Setup` recipes of any layer of primary functionality that might be
assigned to such an instance.  The recipe is:

  * `opsworks_deploy_python::r3-mount-patch`

If you would like to have automatic system and security updates applied to
your instances, you should include and configure the apt unattended upgrades
recipe in the `Setup` recipes for any primary layer:

  * `apt::unattended-upgrades`

This recipe has a number of
[configuration options](https://github.com/opscode-cookbooks/apt#unattended-upgrades-1),
which can be set in the stack Custom JSON.  For example:

  "apt": {
    "unattended_upgrades": {
      "package_blacklist": ["newrelic-sysmond"],
      "mail": "you@example.com"
    }
  }

## Motivation

After reading this, it still may not be clear why so many stack layers
are useful and/or necessary.  The fact is, it is likely unnecessary
for many small deployments which never anticipate using more than a
single server.  However, it is ideal for environments which need
multi-server production clusters, and also want to have identical
single-server staging and development environments.

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
allowing you to automatically spin up new instances or other services
as needed based on a fixed schedule or on server load.  This layered
configuration allows you to easily scale up just those parts of your
deployment which need it (generally the plone instances), or quickly
replace or upgrade instances.


A Simple Plone Deployment Stack
-------------------------------

If you really don't need any fancy redundancy or scalability,
you can make a simple single layer stack.

Just create a [Front End Layer](#front-end-layer), as described above
and assign it the custom recipes for that layer as documented above.
Also, assign it the custom recipes from [Plone Instances
Layer](#plone-instances-layer) and those from the [EBS Snapshots
Layer](#ebs-snapshots-layer).  Set the layer to use EBS Optimized
instances (you will only ever be using one instance), and assign two
EBS volumes at '/mnt/shared/blobs/blobstorage' and
'/mnt/shared/zodb/filestorage'.

You can mount additional EBS volumes for repozo backups if you want
those to persist across server failures and instance stop/starts
(though for catastrophic failures EBS snapshots are probably a better
choice than repozo backups for getting up and running quickly).  You
can add EBS mounts for any additional buildout parts you may want to
include which require persistent storage (e.g. `.../shared/var/solr`).
In theory, you could mount the entire `.../shared/var` as a single EBS
volume, but EBS is much slower than instance storage and is probably
not an ideal place for storing logs, tmp files and other ephemera.
Additionally, using more EBS volumes in parallel provides greater
potential I/O throughput (and OpsWorks allows you to easily use RAID
EBS volumes if you need further performance improvements).

Once your layer is setup, create an App pointing at your repository as
described in [Plone Instances
Application](#plone-instances-application).

Configure your Stack Custom JSON as follows:

    {
        "deploy" : {
            "plone_instances" : "buildout_parts_to_include": ["zeoserver", ...],
            "buildout_extends" : [...],
            "buildout_init_commands" : [{"name" : "zeoserver", "cmd" : "bin/zeoserver", "args" : "console"}]
        },
        "plone_blobs" : {"blob_dir" : "/mnt/shared/blobs/blobstorage"},
        "ebs_snapshots" : {
         "aws_key" : "***** AWS KEY FOR SNAPSHOTTING (IAM USER) *****",
         "aws_secret" : "***** AWS SECRET FOR SNAPSHOTTING (IAM USER) *****"
       }
    }

See [A Custom User with Snapshot Permissions](#a-custom-user-with-snapshot-permissions)
above for info about setting up IAM user credentials for taking EBS
snapshots.

Notice that it's possible to manually include whatever buildout parts
as well as include custom extends files in the deploy JSON.  You can
also add any commands you wish to the supervisor init (in this case we
add our zeoserver).  The recipe will still generate a number of
`client#{n}` parts based on the instance size and launch them via the
system supervisor.

That's all that's needed for a single layer deployment; however,
breaking each bit of functionality (App Servers, DB Servers/Blob
Storage, Front End) into its own layer can offer significant
advantages in exchange for a little extra up-front effort.


## More information

* [A gentle introduction to OpsWorks](http://artsy.github.io/blog/2013/08/27/introduction-to-aws-opsworks/)

* [Official OpsWorks documentation](http://docs.aws.amazon.com/opsworks/latest/userguide/welcome.html)

* [CLI Opsworks](http://docs.aws.amazon.com/cli/latest/reference/opsworks/index.html)

* [Case study of a move from Heroku to OpsWorks (rails application)](http://www.stefanwrobel.com/heroku-to-opsworks)

* Look in the `examples/example-custom-json.json` for a Stack JSON example which includes an egg cache download.


## To Do

* Enable automated copying/pruning of EBS snapshots across regions, to
  allowing recovery from region wide outages.

* Allow cache archives (eggs, etc.) to be stored in private s3 buckets.

* Alternatives for blob storage (S3, Ceph?)

* Rolling deployments, configurable delays between each instance restart

* Convert Solr layer to use OS installed Solr and configure it
  directly, rather than using buildout.


## License && Authors
* Alec Mitchell <alecpm@gmail.com>

With thanks to Jazkarta, Inc. and KCRW Radio
```text
Copyright 2015, Alec Mitchell

Licensed under the BSD License.
```
