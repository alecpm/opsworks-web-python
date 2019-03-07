Chef::Platform::platforms[:ubuntu][">= 16.04"] = {:service=>Chef::Provider::Service::Systemd}
begin
    if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
        Chef::Platform::platforms[:ubuntu][">= 14.04"] = {:service=>Chef::Provider::Service::Systemd}
    end
rescue
    # ignore
end
