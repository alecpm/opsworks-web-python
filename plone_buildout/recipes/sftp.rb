if node["sftp"]["user"]

	node.normal["openssh"]["server"]["match"]["Address #{node["sftp"]["remote_addr"]}"] = {
		"password_authentication" => "yes"
	}

	include_recipe 'openssh'

	group "sftp" do
	end

	homedir = "/home/#{node["sftp"]["user"]}"
	mntdir = "/mnt/srv/www/#{node["sftp"]["user"]}"

	user node["sftp"]["user"] do
		shell "/bin/false"
		gid "sftp"
		password node["sftp"]["password"]
		home homedir
	    supports :manage_home => true
	end

	group "sftp" do
		action :modify
		members node["sftp"]["user"]
		append true
	end

	directory mntdir do
		owner node["sftp"]["user"]
		group "sftp"
		mode "0777"
		action :create
		recursive true
	end

	mount homedir do
		device mntdir
		action [:mount, :enable]
		options "rw,bind"
	end

	service "ssh" do
		action :restart
	end

end
