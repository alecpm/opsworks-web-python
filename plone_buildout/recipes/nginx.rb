include_recipe 'plone_buildout::patches'
node.normal[:nginx][:client_max_body_size] = node[:nginx_plone][:client_max_body_size]

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

if !node['certbot_domains'].empty?
  # Ensure conf file exists
  file "#{node[:nginx][:dir]}/certbot.conf" do
    content " "
    mode 644
    action :create_if_missing
  end
end

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
  pattern "(?<![A-Za-z])rotate"
  line "        rotate #{node['nginx_plone']['log_retention_days']}"
end

replace_or_add "Nginx logrotate daily" do
  path "/etc/logrotate.d/nginx"
  pattern "weekly"
  line "        daily"
end

if node['nginx_plone']['force_reload']
  service "nginx" do
    action :reload
  end
end
