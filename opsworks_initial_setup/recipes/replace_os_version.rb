# Patch Chef service provider for ubuntu
Chef::Platform::platforms[:ubuntu][">= 16.04"] = {:service=>Chef::Provider::Service::Systemd}
begin
    if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
        node.normal['pretend_ubuntu_version'] = true
        Chef::Platform::platforms[:ubuntu][">= 14.04"] = {:service=>Chef::Provider::Service::Systemd}
        file '/etc/lsb-release' do
            content "DISTRIB_ID=Ubuntu\nDISTRIB_RELEASE=18.04\nDISTRIB_CODENAME=bionic\nDISTRIB_DESCRIPTION=\"Ubuntu 18.04.2 LTS pretending to be 14.04\"\n"
            owner 'root'
            group 'root'
            mode '0644'
            action :create
            ignore_failure true
        end
    end
rescue
    # ignore
end
