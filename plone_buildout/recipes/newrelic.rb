node.normal['newrelic']['server_monitoring']['license'] = node['newrelic']['license']
node.normal['newrelic']['application_monitoring']['license'] = node['newrelic']['license']
node.normal['newrelic_meetme_plugin']['license'] = node['newrelic']['license']

services = {}

host_id = node[:opsworks][:stack][:name] + '--' + node[:opsworks][:instance][:hostname]

if (node.recipe?('haproxy::default') ||
    node.recipe?('plone_buildout::haproxy'))
  services['haproxy'] = {
      'name' => host_id,
      'host' => 'localhost',
      'port' => 8080,
      'path' => node[:haproxy][:stats_url] + ';csv',
      'username' => node[:haproxy][:stats_user],
      'password' => node[:haproxy][:stats_password]
    }
end

if (node.recipe?('nginx') || node.recipe?('nginx::default') ||
    node.recipe?('plone_buildout::nginx'))
  services['nginx'] = {
    'name' => host_id,
    'host' => 'localhost',
    'port' => 80,
    'path' => '/_main_status_'
    }
end

if node.recipe?('memcached::default') || node.recipe?('memcached')
  services['memcached'] = {
    'name' => host_id,
    'host' => 'localhost',
    'port' => node[:memcached][:port]
  }
end

if node.recipe?('redis::default') || node.recipe?('redis')
  services['redis'] = {
    'name' => host_id,
    'host' => 'localhost',
    'port' => node['redis']['config']['listen_port'].to_i
  }
end

if (node.recipe?('plone_buildout::varnish') || node.recipe?('varnish') ||
    node.recipe?('varnish::default'))
  # This one is a little trickier, since we can't use the meetme recipes
  install_plugin 'newrelic_varnish_plugin' do
    plugin_version   node[:newrelic][:varnish][:version]
    install_path     node[:newrelic][:varnish][:install_path]
    plugin_path      node[:newrelic][:varnish][:plugin_path]
    download_url     node[:newrelic][:varnish][:download_url] 
    user             node[:newrelic][:varnish][:user]
  end

  # newrelic template
  template "#{node[:newrelic][:varnish][:plugin_path]}/config/newrelic_plugin.yml" do
    source 'newrelic_plugin.yml.erb'
    action :create
    owner node[:newrelic][:varnish][:user]
    notifies :restart, 'service[newrelic-varnish-plugin]', :delayed
    variables 'name' => host_id
  end

  # install bundler gem and run 'bundle install'
  bundle_install do
    path node[:newrelic][:varnish][:plugin_path]
    user node[:newrelic][:varnish][:user]
  end

  # install init.d script and start service
  template "/etc/init.d/newrelic-varnish-plugin" do
    cookbook 'newrelic_plugins'
    source 'service.erb'
    variables({
      :daemon       => './newrelic_varnish_plugin',
      :daemon_dir   => node[:newrelic][:varnish][:plugin_path],
      :plugin_name  => 'Varnish',
      :version      => node[:newrelic][:varnish][:version],
      :run_command  => "sudo -u #{node[:newrelic][:varnish][:user]} bundle exec",
      :service_name => 'newrelic-varnish-plugin'
    })
    action :create
    mode 0755
  end

  # manage service
  service 'newrelic-varnish-plugin' do
    action [:enable, :start]
    subscribes :restart, "template[/etc/init.d/newrelic-varnish-plugin]", :immediately
  end
  Chef::Log.info("Enabled newrelic varnish")

end

# Include any globally configured service plugins
services.update(node['newrelic_meetme_plugin']['services'] || {})
node.normal['newrelic_meetme_plugin']['services'] = services

include_recipe 'newrelic'

if node.recipe?('plone_buildout::instances-setup') && node['plone_instances']['newrelic_tracing']
   # install the python agent in the buildout venv
   node.normal['newrelic']['python_agent']['python_venv']  =
     ::File.join(node[:deploy][node['plone_instances']['app_name']][:deploy_to],
                 'shared', 'env')
  # Append stack name to app name
  node.normal['newrelic']["application_monitoring"]["app_name"] = (
      node[:opsworks][:stack][:name] + ': ' + node['newrelic']["application_monitoring"]["app_name"])
  include_recipe 'python::default'
  include_recipe 'plone_buildout::instances-setup'
  include_recipe 'newrelic::python_agent'
  Chef::Log.info("Enabled newrelic python agent")
end

include_recipe 'newrelic_meetme_plugin' if node['newrelic_meetme_plugin']['services'].length

Chef::Log.info("Enabled newrelic plugins: #{node['newrelic_meetme_plugin']['services']}")

directory "/etc/apt/apt.conf.d" do
  recursive true
  action :create
  mode 0755
end

file "/etc/apt/apt.conf.d/local" do
  content 'Dpkg::Options {
    "--force-confdef";
    "--force-confold";
  }'
  mode 0644
end
