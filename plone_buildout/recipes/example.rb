# Opsworks stuff to allow testing on Vagrant
node.normal[:haproxy][:static_backends] = []
node.normal[:haproxy][:static_applications] = []
node.normal[:haproxy][:rails_backends] = []
node.normal[:haproxy][:rails_applications] = []
node.normal[:haproxy][:nodejs_backends] = []
node.normal[:haproxy][:nodejs_applications] = []
node.normal[:haproxy][:php_backends] = []
node.normal[:haproxy][:php_applications] = []
node.normal[:haproxy][:enable_stats] = true
node.normal[:haproxy][:stats_url] = "/balancer/stats"
node.normal[:haproxy][:stats_user] = "stats"
node.normal[:haproxy][:stats_password] = "stats"
node.normal[:haproxy][:health_check_method] = "HEAD"
node.normal[:haproxy][:health_check_url] = "/misc_/CMFPlone/plone_icon"

def _opsworks_buildout_defaults
  {
    "application_type" => "other",
    :chef_provider => "Timestamped",
    :environment => {},
    "packages" => [],
    :group => "www-data",
    :user => "deploy",
    :home => "/home/deploy",
    "buildout_cache_archives" => [],
    :scm => {
      :scm_type => 'git',
      :repository => 'https://github.com/alecpm/opsworks_example_buildouts.git',
      :revision => 'master',
      :ssh_key => nil
    },
  }
end

instance_defaults = _opsworks_buildout_defaults()
zeo_defaults = _opsworks_buildout_defaults()

node.default[:opsworks] = {}
node.default[:opsworks][:ruby_stack] = 'ruby'
node.default[:opsworks][:ruby_version] = '2.0.0'
node.default[:opsworks][:instance] = {}
node.default[:opsworks][:instance][:hostname] = 'test-host'
node.default[:opsworks][:instance][:private_ip] = "127.0.0.1"
node.default[:opsworks][:instance][:private_dns_name] = "localhost.localdomain"
node.default[:opsworks][:instance][:region] = "us-bogus-1"
node.default[:opsworks][:stack] = {}
node.default[:opsworks][:stack][:name] = 'fake-stack'
node.default[:opsworks][:layers] = {}

# Mocked Opsorks Layer setup
node.default[:opsworks][:layers] = {
  "zeoserver" => {
    :instances => {'instance1' => {:private_dns_name => 'localhost.localdomain', :status => "online"}}
  },
  "plone_instances" => {
    :instances => {'instance1' => {:private_dns_name => 'localhost.localdomain', :status => "online", :backends => 8, :hostname => "instance", :private_ip => '127.0.0.1', :public_ip => '127.0.0.2'}}
  }
}

# This does not actually use CPU count on AWS, but the opsworks estimate of instance cpu capacity (`backends`)
node.default["plone_instances"]["per_cpu"] = 1
node.default["plone_instances"]["enable_celery"] = true
node.default["plone_instances"]["celerybeat"] = true
node.default["plone_instances"]["broker_layer"] = 'plone_instances'
node.default["plone_blobs"]["blob_dir"] = "/mnt/shared/blobstorage"

node.default["plone_instances"]["syslog_facility"] = 'local3'
node.default["plone_zeoserver"]["syslog_facility"] = 'local4'


# Set application dirs
instance_defaults[:deploy_to] = "/srv/instances"
zeo_defaults[:deploy_to] = "/srv/zeoserver"

node.default[:deploy] = {
  "plone_instances" => instance_defaults,
  "zeoserver" => zeo_defaults
}

node.normal['varnish']['storage_size'] = '5M'
node.normal[:nginx][:worker_processes] = 1


node.normal['plone_instances']['newrelic_tracing'] = false
node.normal['plone_instances']['newrelic_tracing_clients'] = 0
node.normal['plone_instances']['traceview_tracing'] = false

# New Relic settings
node.normal['newrelic']['license'] = 'YOUR LICENSE HERE'

# Papertrail settings
node.normal['papertrail']['remote_host'] = 'logs.papertrailapp.com'
node.normal['papertrail']['remote_port'] = 12345 # Your papertrail port

# Traceview settings
node.normal['traceview']['access_key'] = 'YOUR LICENSE HERE'

# These Recipes as run on an opsworks launch

# Setup
# Chef::Log.debug('************************** Running Setup Steps *****************************')
include_recipe "redis::server"
include_recipe "plone_buildout::nginx"
include_recipe "plone_buildout::varnish"
include_recipe "plone_buildout::haproxy"

include_recipe "plone_buildout::zeoserver-setup"
include_recipe "plone_buildout::instances-setup"

# # Deploy
# Chef::Log.debug('************************** Configure Completed Running Deploy Steps *****************************')
include_recipe "plone_buildout::instances-celerybeat"
include_recipe "plone_buildout::zeoserver-deploy"
include_recipe "plone_buildout::instances-deploy"

# # Configure
# Chef::Log.debug('************************** Setup Completed Running Configure Steps *****************************')
include_recipe "plone_buildout::instances-celerybeat"
include_recipe "plone_buildout::zeoserver-configure"
include_recipe "plone_buildout::instances-configure"

include_recipe "plone_buildout::papertrail"
