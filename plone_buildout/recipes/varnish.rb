include_recipe 'plone_buildout::patches'
# The varnish dir should not generate i/o so we mount it as tmpfs
directory '/var/lib/varnish' do
  recursive true
  action :create
end

if node['varnish_plone']['tmpfs_var']
  mount '/var/lib/varnish' do
    fstype 'tmpfs'
    options 'rw,size=256M'
    device 'tmpfs'
    action [:mount, :enable]
  end
end

ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'
# The ephemeral storage is quite a bit faster than root for our cache file
directory ::File.join(ephemeral, '/varnish') do
  recursive true
  action :create
end

node.normal['varnish']['storage_file'] = ::File.join(ephemeral, 'varnish/varnish_storage.bin')

execute 'systemctl-daemon-reload' do
  command '/bin/systemctl --system daemon-reload'
  action :nothing
end

service 'varnish' do
  supports restart: true, reload: true
  action :nothing
end

if node['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
  template node['varnish']['default'] do
    source node['varnish']['conf_source']
    cookbook node['varnish']['conf_cookbook']
    owner 'root'
    group 'root'
    mode 0644
    notifies notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    notifies 'restart', 'service[varnish]'
  end
end

include_recipe "varnish"

if node['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
  service 'varnishncsa' do
    supports restart: true, reload: true
    action node['varnish']['log_daemon'] ? %w(enable start) : %w(disable stop)
  end
end
