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
node.normal[:haproxy][:stats_user] = "stats"
node.normal[:haproxy][:stats_password] = "stats"
node.normal[:haproxy][:health_check_method] = "HEAD"
node.normal[:haproxy][:health_check_url] = "/misc_/CMFPlone/plone_icon"

def _opsworks_buildout_defaults
  {
    "application_type" => "other",
    "chef_provider" => "Timestamped",
    "environment" => {},
    "packages" => [],
    "group" => "www-data",
    "user" => "deploy",
    "home" => "/home/deploy",
    "buildout_cache_archives" => [{:url => nil, :path => 'shared'}],
    :scm => {
      :scm_type => 'git',
      :repository => 'git@github.com:alecpm/opsworks_example_buildouts',
      :revision => 'master',
      :ssh_key => nil
    },
  }
end

instance_defaults = _opsworks_buildout_defaults()
zeo_defaults = _opsworks_buildout_defaults()
solr_defaults = _opsworks_buildout_defaults()

node.default[:opsworks] = {}
node.default[:opsworks][:instance] = {}
node.default[:opsworks][:instance][:backends] = 1
node.default[:opsworks][:instance][:private_ip] = "127.0.0.1"
node.default[:opsworks][:instance][:private_dns_name] = "localhost.localdomain"
node.default[:opsworks][:instance][:region] = "us-bogus-1"
node.default[:opsworks][:layers] = {}

# Mocked Opsorks Layer setup
node.default[:opsworks][:layers] = {
  "zeoserver" => {
    :instances => {'instance1' => {:private_dns_name => 'localhost.localdomain', :status => "online"}}
  },
  "plone_instances" => {
    :instances => {'instance1' => {:private_dns_name => 'localhost.localdomain', :status => "online", :backends => 2, :hostname => "instance", :private_ip => '127.0.0.1', :public_ip => '127.0.0.2'}}
  }
}

# The stack settings (this is what would go into the Custom Stack JSON)
node.default["plone_instances"]["base_config"] = "base.cfg"
node.default["plone_instances"]["app_name"] = "instances"
node.default["plone_instances"]["enable_celery"] = true
node.default["plone_instances"]["zeo_layer"] = "zeoserver"
node.default["plone_instances"]["broker_layer"] = "zeoserver"
# This does not actually use CPU count on AWS, but the opsworks estimate of instance cpu capacity (`backends`)
node.default["plone_instances"]["per_cpu"] = 2 
#node.default["plone_instances"]["instance_count"] = 3
node.default["plone_instances"]["nfs_blobs"] = false
node.default["plone_instances"]["solr_enabled"] = true
node.default["plone_instances"]["solr_layer"] = "zeoserver"
node.default["plone_zeoserver"]["enable_backup"] = false
node.default["plone_zeoserver"]["nfs_blobs"] = false
#node.default["plone_blobs"]["network"] = "127.0.0.0/8"
node.default["plone_blobs"]["layer"] = "zeoserver"
node.default["plone_blobs"]["blob_dir"] = "/srv/instances/shared/var/blobstorage"

# Set application dirs and include sources.cfg for development/staging
instance_defaults[:deploy_to] = "/srv/instances"
instance_defaults['buildout_extends'] = ["cfg/sources.cfg"]
zeo_defaults[:deploy_to] = "/srv/zeoserver"
zeo_defaults['buildout_extends'] = ["cfg/sources.cfg"]
solr_defaults[:deploy_to] = "/srv/solr"
solr_defaults['buildout_extends'] = []
solr_defaults['buildout_cache_archives'] = []

node.default[:deploy] = {
  "instances" => instance_defaults,
  "zeoserver" => zeo_defaults,
  "solr" => solr_defaults
}

# The Recipes as run on an opsworks launch

# Setup
Chef::Log.debug('************************** Running Setup Steps *****************************')
#include_recipe "redis::server"
include_recipe "plone_buildout::nginx"
include_recipe "plone_buildout::varnish"
include_recipe "plone_buildout::haproxy"

#include_recipe "plone_buildout::nfs_blobs"
include_recipe "plone_buildout::zeoserver-setup"
include_recipe "plone_buildout::instances-setup"
# include_recipe "plone_buildout::solr-setup"

# Configure
Chef::Log.debug('************************** Setup Completed Running Configure Steps *****************************')
include_recipe "plone_buildout::zeoserver-configure"
include_recipe "plone_buildout::instances-configure"
# include_recipe "plone_buildout::solr-configure"

# Deploy
Chef::Log.debug('************************** Configure Completed Running Deploy Steps *****************************')
include_recipe "plone_buildout::zeoserver-deploy"
include_recipe "plone_buildout::instances-deploy"
# include_recipe "plone_buildout::solr-deploy"
