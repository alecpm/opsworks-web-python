#
# Cookbook Name:: haproxy
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
node.normal['haproxy_service_provider'] = value_for_platform(
  'ubuntu' => {
    '< 14.04' => Chef::Provider::Service::Debian,
    '14.04' => Chef::Provider::Service::Upstart,
    'default' => Chef::Provider::Service::Systemd
  }
)

begin
  if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
    node.normal['haproxy_service_provider'] = Chef::Provider::Service::Systemd
  end
rescue
    # ignore
end

package "haproxy" do
  retries 3
  retry_delay 5

  action :install
end

if platform?('debian','ubuntu')
  template '/etc/default/haproxy' do
    source 'haproxy-default.erb'
    owner 'root'
    group 'root'
    mode 0644
  end
end

include_recipe 'haproxy::service'

template '/etc/haproxy/haproxy.cfg' do
  cookbook 'plone_buildout'
  source 'haproxy.cfg.erb'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, "service[haproxy]"
end

service 'haproxy' do
  provider node['haproxy_service_provider']
  action [:enable, :start]
end
