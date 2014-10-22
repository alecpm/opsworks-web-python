ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'

default["plone_zeoserver"]["app_name"] = "zeoserver"
default["plone_zeoserver"]["enable_backup"] = true
default["plone_zeoserver"]["blob_dir"] = nil
default["plone_zeoserver"]["nfs_blobs"] = false
default["plone_zeoserver"]["gluster_blobs"] = false

# NFS shared blobs should be assigned to their own layer
default["plone_blobs"]["layer"] = "shared_blobs"
default["plone_blobs"]["nfs_export_dir"] = '/srv/exports'
default["plone_blobs"]["gluster_export_dir"] = ::File.join(ephemeral, 'gluster-exports')
default["plone_blobs"]["network"] = nil
default["plone_blobs"]["host"] = nil
default["plone_blobs"]["servers"] = nil
default["plone_blobs"]["gluster_volume"] = "blobs"
default["plone_blobs"]["nfs_mount_options"] = "auto,rw,noatime,nodiratime"
default["plone_blobs"]["gluster_mount_options"] = "auto,rw,direct-io-mode=disable"
# Store gluster config in export directory and bind mount it into the
# real configuration locaton.  This is unnecessary if your instance is
# EBS backed, but is useful on a VPS instance with a fixed IP
default["plone_blobs"]["gluster_store_config_in_exports"] = false
default["plone_blobs"]["blob_dir"] = nil # Use if using shared blobs, but not NFS/Gluster, will symlink into zeoserver and instances

default["plone_instances"]["base_config"] = "cfg/base.cfg"  # This must be set
default["plone_instances"]["app_name"] = "plone_instances"  # This must be set
default["plone_instances"]["site_id"] = "Plone"  # This must be set for VHosting
default["plone_instances"]["per_cpu"] = 2 # Instances per server CPU
default["plone_instances"]["instance_count"] = nil
default["plone_instances"]["shared_blobs"] = true # Otherwise store blobs in DB
default["plone_instances"]["nfs_blobs"] = false
default["plone_instances"]["gluster_blobs"] = false
default["plone_instances"]["zodb_cache_size"] = nil
default["plone_instances"]["persistent_cache"] = true
default["plone_instances"]["zserver_threads"] = nil
default["plone_instances"]["sticky_sessions"] = false
default["plone_instances"]["restart_delay"] = 0

# Relstorage stuff
default["plone_instances"]["enable_relstorage"] = false
default["plone_instances"]["relstorage"] = {}
default["plone_instances"]["relstorage"]["db"] = {"type" => "postgres", "dsn" => nil,"name" => nil, "host" => nil, 
  "user" => nil, "password" => nil}
default["plone_instances"]["relstorage"]["enable_cache"] = false
default["plone_instances"]["relstorage"]["config"] = 'cfg/relstorage.cfg'
default["plone_instances"]["relstorage"]["cache_servers"] = nil # host:port strings will be automatically set
default["plone_instances"]["relstorage"]["enable_pack"] = false # set to true on one instance deployment
default["plone_instances"]["relstorage"]["pack_days"] = 7
default["plone_instances"]["relstorage"]["two_stage_pack"] = false

# Zeo stuff
default["plone_instances"]["zeo_layer"] = "zeoserver"
default["plone_instances"]["zeo"] = {"address" => nil}

# Celery stuff
default["plone_instances"]["enable_celery"] = false
default["plone_instances"]["celerybeat"] = false
# Broker will generally be attached to an exisitng layer
default["plone_instances"]["broker_layer"] = "celery_broker"
# Set the host if e.g. you want to use an ElastiCache Redis cluster.
# The port if you're using an alternative port/broker
default["plone_instances"]["broker"] = {"host" => nil, "port" => 6379}

# Solr stuff
default["plone_instances"]["solr_enabled"] = false
default["plone_instances"]["solr_layer"] = "solr"
default["plone_instances"]["solr_host"] = nil

# Solr Instance
default["plone_solr"]["app_name"] = "solr"

# EBS Snapshot automation
default["ebs_snapshots"]["keep"] = 15  # 15 snapshots per volume
default["ebs_snapshots"]["hour"] = "8"
default["ebs_snapshots"]["minute"] = "0"
default["ebs_snapshots"]["weekday"] = "0-6"
default["ebs_snapshots"]["aws_key"] = nil
default["ebs_snapshots"]["aws_secret"] = nil

# Nginx config options
default['nginx_plone']['enable_ssi'] = false
default['nginx_plone']['additional_servers'] = nil
default['nginx_plone']['additional_config'] = nil
default['nginx_plone']['additional_ssl_config'] = nil
default['nginx_plone']['proxy_port'] = 6081

# Varnish config options
default['varnish_plone']['grace'] = 60
default['varnish_plone']['default_ttl'] = 300

# Change default configs for other packages
node.normal["redis"]["config"]["listen_addr"] = "0.0.0.0"
node.normal["redis"]["config"]["dir"] = ::File.join(ephemeral, 'redis')
node.normal["redis"]["config"]["vm"][:vm_swap_file] = ::File.join(ephemeral, 'redis/redis.swap')
node.normal[:haproxy][:balance] = "leastconn"
node.normal[:haproxy][:retries] = 3
node.normal[:haproxy][:check_interval] = 10000
node.normal[:haproxy][:server_timeout] = '900s'
