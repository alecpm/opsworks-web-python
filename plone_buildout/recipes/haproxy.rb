# Define the rsyslog service, for restarting as needed. It's
# ever-present on ubuntu
service node['rsyslog']['service_name'] do
  supports :restart => true, :reload => true, :status => true
  action   :nothing
  provider Chef::Provider::Service::Upstart
end

include_recipe "rsyslog::default"

template '/etc/rsyslog.d/haproxy-log.conf' do
  source 'haproxy-log.conf.erb'
  cookbook 'plone_buildout'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, "service[rsyslog]"
end

template "/etc/logrotate.d/haproxy-rsyslog" do
  backup false
  source "haproxy-logrotate.erb"
  owner "root"
  group "root"
  mode 0644
end

package 'haproxy' do
  action :install
end

include_recipe 'haproxy::service'

template '/etc/haproxy/haproxy.cfg' do
  source 'haproxy.cfg.erb'
  cookbook 'plone_buildout'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, "service[haproxy]", :delayed
end

service 'haproxy' do
  action [:enable, :start]
end
