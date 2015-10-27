ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'

default["plone_zeoserver"]["app_name"] = "zeoserver"
default["plone_zeoserver"]["enable_backup"] = false
default["plone_zeoserver"]["enable_pack"] = true
default["plone_zeoserver"]["filestorage_dir"] = ::File.join(ephemeral, 'shared', 'zodb', 'filestorage')
default["plone_zeoserver"]["nfs_blobs"] = false
default["plone_zeoserver"]["gluster_blobs"] = false
default["plone_zeoserver"]["syslog_facility"] = nil
default["plone_zeoserver"]["syslog_level"] = 'INFO'

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
default["plone_blobs"]["blob_dir"] = nil # Use if using shared blobs, will symlink into zeoserver and instances

default["plone_instances"]["base_config"] = "cfg/base.cfg"  # This must be set
default["plone_instances"]["app_name"] = "plone_instances"  # This must be set
default["plone_instances"]["site_id"] = "Plone"  # This must be set for VHosting
default["plone_instances"]["subsites"] = {}  # mapping of vhost name to site path
default["plone_instances"]["subsite_config"] = {}  # mapping of vhost name to additional_config
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
default["tmpdir"]["global_tmp"] = false
default["tmpdir"]["tmpfs"] = false
default["tmpdir"]["tmpfs_size"] = '1G'

# Relstorage stuff
default["plone_instances"]["enable_relstorage"] = false
default["plone_instances"]["relstorage"] = {}
default["plone_instances"]["relstorage"]["db"] = {
    "type" => "postgres",
    "dsn" => nil,
    "name" => nil,
    "host" => nil,
    "user" => nil,
    "password" => nil
}
default["plone_instances"]["relstorage"]["enable_cache"] = true
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

# Metrics
# Newrelic
default["plone_instances"]["newrelic_tracing"] = false
default['newrelic']["application_monitoring"]["app_name"] = node['plone_instances']['app_name']
default['newrelic']["application_monitoring"]["browser_monitoring"]["auto_instrument"] = true
default['newrelic']["application_monitoring"]["transaction_tracer"]["slow_sql"] = false
default['newrelic']["application_monitoring"]["transaction_tracer"]["record_sql"] = 'raw'

# Tracelytics
default["plone_instances"]["traceview_tracing"] = false
default["plone_instances"]["traceview_sample_rate"] = 0.1
# number of clients to run tracing on, 0 for all
default["plone_instances"]["tracing_clients"] = 1
# Papertrail
default["plone_instances"]["syslog_facility"] = nil
default["plone_instances"]["syslog_level"] = 'INFO'

# Solr Instance
default["plone_solr"]["app_name"] = "solr"
default["plone_solr"]["enable_papertrail"] = false
default["plone_solr"]["data_dir"] = ::File.join(ephemeral, 'shared', 'solr')

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
default['nginx_plone']['log_retention_days'] = 14
default['nginx_plone']['force_reload'] = false

# Varnish config options
default['varnish_plone']['grace'] = 60
default['varnish_plone']['default_ttl'] = 300

# Change default configs for other packages
include_attribute "redis"
node.default["redis"]["config"]["listen_addr"] = "0.0.0.0"
node.default["redis"]["config"]["dir"] = ::File.join(ephemeral, 'redis')
node.default["redis"]["config"]["vm"][:vm_swap_file] = ::File.join(ephemeral, 'redis/redis.swap')

include_attribute "haproxy"
node.default[:haproxy][:balance] = "leastconn"
node.default[:haproxy][:retries] = 3
node.default[:haproxy][:check_interval] = 10000
node.default[:haproxy][:server_timeout] = '900s'
node.default[:haproxy][:sticky_sessions] = false
node.default[:haproxy][:rise] = 1
node.default[:haproxy][:fall] = 5

include_attribute "newrelic"
node.default[:newrelic][:varnish][:version] = 'v0.0.5'
node.default[:newrelic][:varnish][:install_path] = "/opt/newrelic"
node.default[:newrelic][:varnish][:plugin_path] = "#{node[:newrelic][:varnish][:install_path]}/newrelic_varnish_plugin"
node.default[:newrelic][:varnish][:download_url] = "https://github.com/varnish/newrelic_varnish_plugin/archive/#{node[:newrelic][:varnish][:version]}.tar.gz"
node.default[:newrelic][:varnish][:user] = "root"

node.default['newrelic']['python_agent']['python_version'] = '2.40.0.34'
node.default["apt"]["unattended_upgrades"]["package_blacklist"] = ["newrelic-sysmond"]

# Version update
node.default[:s3fs_fuse][:version] = '1.74'

# Ubuntu install seems to put the bluepill binary in another location
node.default["bluepill"]["bin"] = "/usr/local/bin/bluepill"
