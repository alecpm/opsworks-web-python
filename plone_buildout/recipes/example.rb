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

# Mocked Opsorks Layer setup
node.default[:opsworks][:layers] = {
  "zeoserver" => {
    :instances => {'instance1' => {:private_dns_name => '127.0.0.1', :status => "online"}}
  },
  "plone_instances" => {
    :instances => {'instance1' => {:private_dns_name => '127.0.0.1', :status => "online", :backends => 8, :hostname => "instance", :private_ip => '127.0.0.1', :public_ip => '127.0.0.2'}}
  },
  "shared_blobs" => {
    :instances => {'instance1' => {:private_dns_name => '127.0.0.1', :status => "online", :backends => 8, :hostname => "instance", :private_ip => '127.0.0.1', :public_ip => '127.0.0.2'}}
  }
}

# This does not actually use CPU count on AWS, but the opsworks estimate of instance cpu capacity (`backends`)
node.default["plone_instances"]["per_cpu"] = 2
node.default["plone_instances"]["enable_celery"] = false
node.default["plone_instances"]["celerybeat"] = false
node.default["plone_instances"]["broker_layer"] = 'plone_instances'

node.default["plone_instances"]["syslog_facility"] = 'local3'
node.default["plone_zeoserver"]["syslog_facility"] = 'local4'


# Set application dirs
instance_defaults[:deploy_to] = "/srv/www/instances"
zeo_defaults[:deploy_to] = "/srv/www/zeoserver"

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

# Egg cache
node.normal['plone_instances']["buildout_cache_archives"] = [{"url" => "https://eggs-bucket.s3.amazonaws.com/kcrw-plone-eggs.tgz", "path" => "shared"}]

# NFS
node.normal['plone_instances']['nfs_blobs'] = true
node.normal['plone_zeoserver']['nfs_blobs'] = true

# These Recipes as run on an opsworks launch
# Upstart job depends on the /srv/www mountpoint
directory '/mnt/srv' do
  recursive true
  action :create
end

directory '/srv/www' do
  recursive true
  action :create
end

mount '/srv/www' do
  device '/mnt/srv'
  fstype 'none'
  options 'bind,rw'
  action [:mount, :enable]
end

# Setup
# Chef::Log.debug('************************** Running Setup Steps *****************************')
include_recipe "opsworks_initial_setup"
include_recipe "haproxy"
include_recipe "plone_buildout::haproxy"
#include_recipe "redis::server"
#include_recipe "plone_buildout::nfs_blobs"
include_recipe "plone_buildout::nginx"
include_recipe "plone_buildout::varnish"

include_recipe "plone_buildout::zeoserver-setup"
include_recipe "plone_buildout::instances-setup"
include_recipe "bluepill"
include_recipe "s3fs-fuse"

# # Deploy
# Chef::Log.debug('************************** Configure Completed Running Deploy Steps *****************************')
#include_recipe "plone_buildout::instances-celerybeat"
include_recipe "deploy"
include_recipe "plone_buildout::zeoserver-deploy"
include_recipe "plone_buildout::instances-deploy"

# # Configure
# Chef::Log.debug('************************** Setup Completed Running Configure Steps *****************************')
#include_recipe "plone_buildout::instances-celerybeat"
include_recipe "plone_buildout::zeoserver-configure"
include_recipe "plone_buildout::instances-configure"

# include_recipe "plone_buildout::papertrail"

# S3 filesystem

