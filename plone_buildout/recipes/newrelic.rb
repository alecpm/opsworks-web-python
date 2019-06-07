include_recipe 'plone_buildout::patches'
node.normal['newrelic']['application_monitoring']['license'] = node['newrelic']['application_monitoring']['license'] || node['newrelic']['license']

services = {}

host_id = node[:opsworks][:stack][:name] + '--' + node[:opsworks][:instance][:hostname]

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

if node['newrelic']['infrastructure']
  ubuntu_names = {
    7 => 'wheezy',
    8 => 'jessie',
    9 => 'stretch',
    10 => 'buster',
    12 => 'precise',
    14 => 'trusty',
    16 => 'xenial',
    18 => 'bionic',
  }
  distro_name = ubuntu_names[node['platform_version'].to_i]
  if node.pretend_ubuntu_version
    distro_name = 'bionic'
  end

  apt_repository 'newrelic-infra' do
    uri node['newrelic']['repository']['infrastructure']['uri']
    distribution distro_name
    components node['newrelic']['repository']['infrastructure']['components']
    key node['newrelic']['repository']['infrastructure']['key']
    arch 'amd64'
  end

  execute "apt-get-update" do
    command "apt-get update"
    ignore_failure true
  end

  package 'newrelic-infra' do
    action :install
  end
  service 'newrelic-sysmond' do
    action [:disable, :stop]
    ignore_failure true
  end
  service 'newrelic-infra' do
    action [:enable, :start]
    ignore_failure true
    case node['platform']
    when 'ubuntu'
      if (node['platform_version'].to_f <= 14.04 && node['platform_version'].to_f >= 9.10)
        provider Chef::Provider::Service::Upstart
      end
    end
  end
  template '/etc/newrelic-infra.yml' do
    source 'newrelic-infra.yml.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      :resource => {
        :license => node['newrelic']['license']
      }
    )
    notifies :restart, 'service[newrelic-infra]', :delayed
  end
  if node.recipe?('plone_buildout::nginx')
    package 'newrelic-infra-integrations' do
      action :install
    end
    template '/etc/newrelic-infra/integrations.d/nginx-config.yml' do
      source 'newrelic-nginx-infra.yml.erb'
      mode '0644'
      owner 'root'
      group 'root'
      notifies :restart, 'service[newrelic-infra]', :delayed
    end
  end
end

if node['plone_instances']['newrelic_tracing']
  node.normal['newrelic']["application_monitoring"]["app_name"] = (
      node[:opsworks][:stack][:name] + ': ' + node['newrelic']["application_monitoring"]["app_name"])
  include_recipe 'python::default'
  include_recipe 'newrelic::python_agent'
  if node.recipe?('plone_buildout::instances-setup')
    include_recipe 'plone_buildout::instances-setup'
  end
  Chef::Log.info("Enabled newrelic python agent")
end
