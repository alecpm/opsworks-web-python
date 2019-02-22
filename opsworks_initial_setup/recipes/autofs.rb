package "autofs" do
  retries 3
  retry_delay 5
end

autofs_service_provider = value_for_platform(
  'ubuntu' => {
    '< 14.04' => Chef::Provider::Service::Debian,
    '14.04' => Chef::Provider::Service::Upstart,
    'default' => Chef::Provider::Service::Systemd
  }
)
begin
  if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
    autofs_service_provider = Chef::Provider::Service::Systemd
  end
rescue
    # ignore
end


service "autofs" do
  provider autofs_service_provider
  supports :status => true, :restart => false, :reload => true
  action [ :enable, :start ]
end

template node[:opsworks_initial_setup][:autofs_map_file] do
  source "automount.opsworks.erb"
  mode "0444"
  owner "root"
  group "root"
end

ruby_block "Update autofs loglevel" do
  block do
    handle_to_master = Chef::Util::FileEdit.new(AutoFs.config(node))
    handle_to_master.insert_line_if_no_match(
      /^LOGGING=/,
      "LOGGING=verbose"
    )
    handle_to_master.write_file
  end
  not_if { ::File.read(AutoFs.config(node)) =~ /^LOGGING=/ }
end

ruby_block "Update autofs configuration" do
  block do
    handle_to_master = Chef::Util::FileEdit.new("/etc/auto.master")
    handle_to_master.insert_line_if_no_match(
      node[:opsworks_initial_setup][:autofs_map_file],
      "/- #{node[:opsworks_initial_setup][:autofs_map_file]} -t 3600 -n 1"
    )
    handle_to_master.write_file
  end
  notifies :restart, "service[autofs]", :immediately
  not_if { ::File.read('/etc/auto.master').include?('auto.opsworks') }
end
