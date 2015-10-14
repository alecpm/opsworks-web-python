node.normal[:nginx][:client_max_body_size] = '128m'

ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'
log_dir = ::File.join(ephemeral, '/var/log/nginx')
# Store logs on large fast instance storage
directory log_dir do
  recursive true
  action :create
end

directory '/var/log/nginx' do
  action :create
end

mount '/var/log/nginx' do
  device log_dir
  fstype 'none'
  options "bind,rw"
  action [:mount, :enable]
end

include_recipe 'nginx'

template "#{node[:nginx][:dir]}/sites-available/instances" do
  source "instances.nginx.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[nginx]", :delayed
end

link "#{node[:nginx][:dir]}/sites-enabled/default" do
  action :delete
end

link "#{node[:nginx][:dir]}/sites-enabled/instances" do
  to "#{node[:nginx][:dir]}/sites-available/instances"
  owner "root"
  group "root"
  mode 0644
end

replace_or_add "Nginx logrotate 2 weeks" do
  path "/etc/logrotate.d/nginx"
  pattern "^\s*rotate\s+"
  line "        rotate #{node['nginx_plone']['log_retention_days']}"
end

if node['nginx_plone']['force_reload']
  service nginx do
    action :reload
  end
end
