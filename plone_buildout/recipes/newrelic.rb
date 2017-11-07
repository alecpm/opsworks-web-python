include NewRelic::Helpers

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

if node['newrelic']['infrastructure']
  include_recipe 'newrelic::infrastructure_agent'
end
if node['newrelic']['servers']
  include_recupe 'newrelic::server_monitor_agent'
end

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

  # Manual python agent config
  newrelic_repository
  config_file = node['newrelic']['python_agent']['config_file']
  config_dir = ::File.dirname(config_file)
  directory config_dir do
    owner 'root'
    group 'root'
    recursive true
  end
  template config_file do
    cookbook node['newrelic']['python_agent']['template']['cookbook']
    source node['newrelic']['python_agent']['template']['source']
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      :resource => {
        license => node['newrelic']['license'],
        app_name => node['newrelic']['application_monitoring']['app_name'],
        version => node['newrelic']['python_agent']['python_version'],
        high_security => node['newrelic']['application_monitoring']['high_security'],
        enabled => node['newrelic']['application_monitoring']['enabled'],
        logfile => node['newrelic']['application_monitoring']['logfile'],
        loglevel => node['newrelic']['application_monitoring']['loglevel'],
        daemon_ssl => node['newrelic']['application_monitoring']['daemon']['ssl'],
        capture_params => node['newrelic']['application_monitoring']['capture_params'],
        ignored_params => node['newrelic']['application_monitoring']['ignored_params'],
        transaction_tracer_enable => node['newrelic']['application_monitoring']['transaction_tracer']['enable'],
        transaction_tracer_threshold => node['newrelic']['application_monitoring']['transaction_tracer']['threshold'],
        transaction_tracer_record_sql => node['newrelic']['application_monitoring']['transaction_tracer']['record_sql'],
        transaction_tracer_stack_trace_threshold => node['newrelic']['application_monitoring']['transaction_tracer']['stack_trace_threshold'],
        transaction_tracer_slow_sql => node['newrelic']['application_monitoring']['transaction_tracer']['slow_sql']),
        transaction_tracer_explain_threshold => node['newrelic']['application_monitoring']['transaction_tracer']['explain_threshold'],
        error_collector_enable => node['newrelic']['application_monitoring']['error_collector']['enable']),
        error_collector_ignore_errors => node['newrelic']['application_monitoring']['error_collector']['ignore_errors'],
        browser_monitoring_auto_instrument => node['newrelic']['application_monitoring']['browser_monitoring']['auto_instrument']),
        cross_application_tracer_enable => node['newrelic']['application_monitoring']['cross_application_tracer']['enable']),
        feature_flag => node['newrelic']['python_agent']['feature_flag'],
        thread_profiler_enable => node['newrelic']['application_monitoring']['thread_profiler']['enable'])
      }
    )
    sensitive true
    action :create
  end
  python_pip 'newrelic' do
    virtualenv node[:deploy][node['plone_instances']['app_name']]['venv'] || (node['newrelic']['python_agent']['python_venv'] unless node['newrelic']['python_agent']['python_venv'].nil?)
    version node['newrelic']['python_agent']['python_version'] unless node['newrelic']['python_agent']['python_version'].nil?
    action :install
  end
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
