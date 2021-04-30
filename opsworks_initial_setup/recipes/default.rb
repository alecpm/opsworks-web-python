include_recipe 'opsworks_initial_setup::replace_os_version'
if node[:ec2] && (node[:ec2][:instance_type] == 't1.micro' ||
                  node['opsworks_initial_setup']['swapfile_instancetypes'] && node['opsworks_initial_setup']['swapfile_instancetypes'].include?(node[:ec2][:instance_type]))
  include_recipe 'opsworks_initial_setup::swap'
end
if node['nginx_plone']['enable_http2']
  node.normal[:opsworks_initial_setup][:sysctl]['net.core.default_qdisc'] = 'fq'
  node.normal[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_congestion_control'] = 'bbr'
  node.normal[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_notsent_lowat'] = '16384'
end
include_recipe 'opsworks_initial_setup::sysctl'
include_recipe 'opsworks_initial_setup::limits'
if infrastructure_class?('ec2')
  include_recipe 'opsworks_initial_setup::bind_mounts'
  include_recipe 'opsworks_initial_setup::vol_mount_point'
end
include_recipe 'opsworks_initial_setup::remove_landscape'
include_recipe 'opsworks_initial_setup::ldconfig'

include_recipe 'opsworks_initial_setup::yum_conf'
include_recipe 'opsworks_initial_setup::tweak_chef_yum_dump'
include_recipe 'opsworks_initial_setup::setup_rhel_repos'

include_recipe 'opsworks_initial_setup::package_procps'
include_recipe 'opsworks_initial_setup::package_ntpd'
include_recipe 'opsworks_initial_setup::package_vim'
include_recipe 'opsworks_initial_setup::package_sqlite'
include_recipe 'opsworks_initial_setup::package_screen'

if node['system'] && node['system']['timezone']
  file '/etc/timezone' do
    content node['system']['timezone']
    mode '0644'
    owner 'root'
    group 'root'
  end
  execute 'update_timezone' do
    command 'dpkg-reconfigure --frontend noninteractive tzdata'
  end
end
