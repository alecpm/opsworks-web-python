normal[:opsworks_initial_setup][:bind_mounts][:mounts]['/var/log/nginx'] = "#{node[:opsworks_initial_setup][:ephemeral_mount_point]}/var/log/nginx"
normal[:opsworks_initial_setup][:sysctl]['fs.inotify.max_user_watches'] = 262144
