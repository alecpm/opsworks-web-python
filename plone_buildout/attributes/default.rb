ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'

node.normal['pretend_ubuntu_version'] = nil
begin
    if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
        node.normal['pretend_ubuntu_version'] = true
    end
rescue
    # ignore
end

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
default["plone_instances"]["relstorage"]["cache_poll_interval"] = 60 # Only enabled if caching is turned on and cached are available
default["plone_instances"]["relstorage"]["config"] = 'cfg/relstorage.cfg'
default["plone_instances"]["relstorage"]["cache_servers"] = nil # host:port strings will be automatically set
default["plone_instances"]["relstorage"]["enable_pack"] = false # set to true on one instance deployment
default["plone_instances"]["relstorage"]["pack_days"] = 7
default["plone_instances"]["relstorage"]["two_stage_pack"] = false
default["plone_instances"]["relstorage"]["pack_gc"] = true
default["plone_instances"]["relstorage"]["truncate_refs"] = false
default["plone_instances"]["relstorage"]["read_replicas"] = []
default["plone_instances"]["relstorage"]["include_rw_in_ro"] = false

# Zeo stuff
default["plone_instances"]["zeo_layer"] = "zeoserver"
default["plone_instances"]["zeo"] = {"address" => nil}

# Celery stuff
default["plone_instances"]["enable_celery"] = false
default["plone_instances"]["celerybeat"] = false
default["plone_instances"]["celery_args"] = ''
default["plone_instances"]["beat_args"] = ''
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
default["new_relic"]["servers"] = true
default["new_relic"]["infrastructure"] = false
default['newrelic']["application_monitoring"]["app_name"] = node['plone_instances']['app_name']
default['newrelic']["application_monitoring"]["browser_monitoring"]["auto_instrument"] = false
default['newrelic']["application_monitoring"]["transaction_tracer"]["slow_sql"] = true
default['newrelic']["application_monitoring"]["transaction_tracer"]["record_sql"] = 'raw'

# Tracelytics
# default["plone_instances"]["traceview_tracing"] = false
# default["plone_instances"]["traceview_sample_rate"] = 0.1
# number of clients to run tracing on, 0 for all
# default["plone_instances"]["tracing_clients"] = 1
# Papertrail
# default["plone_instances"]["syslog_level"] = 'INFO'
# default["plone_instances"]["syslog_facility"] = nil

# Solr Instance
default["plone_solr"]["app_name"] = "solr"
# default["plone_solr"]["enable_papertrail"] = false
default["plone_solr"]["data_dir"] = ::File.join(ephemeral, 'shared', 'solr')

# EBS Snapshot automation
default["ebs_snapshots"]["keep"] = 15  # 15 snapshots per volume
default["ebs_snapshots"]["hour"] = "8"
default["ebs_snapshots"]["minute"] = "0"
default["ebs_snapshots"]["weekday"] = "0-6"
default["ebs_snapshots"]["aws_key"] = nil
default["ebs_snapshots"]["aws_secret"] = nil

# Nginx config options
default[:nginx][:worker_processes] = "auto"
default[:nginx][:additional_event_config] = "use epoll;"
default[:nginx][:additional_server_config] = nil

default['nginx_plone']['enable_ssi'] = false
default['nginx_plone']['enable_http2'] = false
default['nginx_plone']['additional_servers'] = nil
default['nginx_plone']['additional_config'] = nil
default['nginx_plone']['additional_ssl_config'] = nil
default['nginx_plone']['default_config'] = nil
default['nginx_plone']['default_ssl_config'] = nil
default['nginx_plone']['proxy_port'] = 6081
default['nginx_plone']['log_rotation_freq'] = 'daily'
default['nginx_plone']['log_retention_count'] = 14
default['nginx_plone']['force_reload'] = false
default['nginx_plone']['client_max_body_size'] = '128m'
default['nginx_plone']['hsts_header'] = ''
default['nginx_plone']['csp_header'] = ''
default['nginx_plone']['additional_location_block_config'] = ''
default['nginx_plone']['disable_server_tokens'] = true
default['nginx_plone']['extra_headers'] = {
    'Server' => 'nginx',
}

# Varnish config options
default['varnish_plone']['grace'] = 60
default['varnish_plone']['default_ttl'] = 300
default['varnish_plone']['tmpfs_var'] = true
default['varnish']['use_default_repo'] = false
default['varnish']['log_daemon'] = false
node.normal['varnish']['vcl_cookbook'] = 'plone_buildout'
node.normal["varnish"]["vcl_source"] = 'default.vcl.erb'
if node['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
    node.normal["varnish"]["vcl_source"] = 'default.vcl4.erb'
    node.normal['varnish']['conf_cookbook'] = 'plone_buildout'
    node.normal['varnish']['conf_source'] = 'varnish.service.erb'
    node.normal['varnish']['default'] = '/etc/systemd/system/varnish.service'
    node.normal['varnish']['reload_cmd'] = '/usr/share/varnish/varnishreload'
    node.normal['varnish']['instance_name'] = "#{node['hostname']}"
    node.normal['varnish']['secondary_listen_address'] = nil
    node.normal['varnish']['secondary_listen_port'] = nil
else
    node.normal["varnish"]["vcl_source"] = 'default.vcl.erb'
end

# Change default configs for other packages
include_attribute "redis"
node.default["redis"]["config"]["listen_addr"] = "0.0.0.0"
node.default["redis"]["config"]["dir"] = ::File.join(ephemeral, 'redis')
node.default["redis"]["config"]["vm"][:vm_swap_file] = ::File.join(ephemeral, 'redis/redis.swap')
node.default["redisio"]["package_install"] = true
node.default["redisio"]["default_settings"]["address"] = "0.0.0.0"
node.normal["redisio"]["servers"] = [
    {'name' => 'redis',
     'port' => '6379',
     'address'=> '0.0.0.0',
    }
]

include_attribute "haproxy"
node.default[:haproxy][:balance] = "leastconn"
node.default[:haproxy][:retries] = 3
node.default[:haproxy][:check_interval] = 10000
node.default[:haproxy][:server_timeout] = '900s'
node.default[:haproxy][:sticky_sessions] = false
node.default[:haproxy][:rise] = 1
node.default[:haproxy][:fall] = 5

include_attribute "newrelic"

node.default[:newrelic]['python_agent']['python_version'] = '2.100.0.84'
node.default[:newrelic]['repository']['infrastructure']['key'] = 'https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg'
node.default[:newrelic]['repository']['infrastructure']['ssl_verify'] = true
node.default[:newrelic]['repository']['infrastructure']['uri'] = 'https://download.newrelic.com/infrastructure_agent/linux/apt'
node.default[:newrelic]['repository']['infrastructure']['components'] = ['main']
node.default["apt"]["unattended_upgrades"]["package_blacklist"] = ["newrelic-sysmond"]

# Version update
node.default[:s3fs_fuse][:version] = '1.74'

# Certbot domains
node.default['certbot_domains'] = []
node.default['certbot_email'] = nil

if node['pretend_ubuntu_version']
    node.normal['nfs']['service_provider']['idmap'] = Chef::Provider::Service::Systemd
    node.normal['nfs']['service_provider']['portmap'] = Chef::Provider::Service::Systemd
    node.normal['nfs']['service_provider']['lock'] = Chef::Provider::Service::Systemd
    default['nfs']['service']['lock'] = 'rpc-statd'
    default['nfs']['service']['idmap'] = 'nfs-idmapd'
end

if node.normal['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
    node.normal['supervisor']['dir'] = '/etc/supervisor/conf.d'
end
