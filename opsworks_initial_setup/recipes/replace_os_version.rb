if File.readlines("/etc/lsb-release").grep(/pretending to be 14\.04/).size > 0
    file "/etc/lsb-release" do
        content 'DISTRIB_ID=Ubuntu\nDISTRIB_RELEASE=18.04\nDISTRIB_CODENAME=bionic\nDISTRIB_DESCRIPTION="Ubuntu 18.04.2 LTS"'
        owner 'root'
        group 'root'
        mode '0644'
        action :create
    end
end
