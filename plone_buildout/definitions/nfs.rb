define :blob_mounts do
  deploy = params[:deploy_data]
  use_gluster = params[:use_gluster]

  group = deploy[:group] || 'www-data'
  owner = deploy[:user] || 'deploy'
  ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/mnt'
  base_dir = ::File.join(deploy[:deploy_to], "shared")
  mount_dir = ::File.join(ephemeral, "shared", "blobs")
  blob_dir = ::File.join(base_dir, "var", "blobstorage")
  blob_mount_dir = File.join(mount_dir, "blobstorage")

  # Create the blob dir and link early, and ensure they have the
  # right ownership/permissions
  directory mount_dir do
    owner owner
    group group
    mode 0755
    recursive true
    action :create
  end
  directory ::File.join(base_dir, "var") do
    owner owner
    group group
    mode 0755
    recursive true
    action :create
  end
  directory blob_mount_dir do
    owner owner
    group group
    mode 0750
    recursive true
    action :create
  end

  # Link mounts to the correct location
  link blob_dir do
    to blob_mount_dir
    owner owner
    group group
    action :create
  end

  host = node["plone_blobs"]["host"]
  layer = node["plone_blobs"]["layer"]
  storage_instances = []
  if use_gluster
    include_recipe "glusterfs::client"
    gluster_servers = node["plone_blobs"]["servers"]
    host = gluster_servers[0] if gluster_servers && !gluster_servers.empty?
  end
  if !host && layer && node[:opsworks] && node[:opsworks][:layers] && node[:opsworks][:layers][layer] && node[:opsworks][:layers][layer][:instances]
    node[:opsworks][:layers][layer][:instances].each {
      |name, instance| storage_instances.push(instance) if instance[:status] == "online"
    }
    if !storage_instances.empty?
      host = storage_instances[0][:private_ip]
    end
  end
  if host
    share = use_gluster ? "/#{node["plone_blobs"]["gluster_volume"]}" : node["plone_blobs"]["nfs_export_dir"]
    mount_type = use_gluster ? "glusterfs" : "nfs"
    mount_options = node["plone_blobs"]["nfs_mount_options"]
    if use_gluster
      mount_options = node["plone_blobs"]["gluster_mount_options"]
      if storage_instances.length > 1
        # Avoid duplicate entries
        orig_options = mount_options
        storage_instances.each { |instance|
          mount mount_dir do
            device "#{instance[:private_ip]}:#{share}"
            fstype mount_type
            options orig_options
            action [:disable]
          end
        }
        # Add redundancy
        mount_options << ",backupvolfile-server=#{storage_instances[1][:private_ip]}"
      end
    end
    mount_options << ",_netdev,nobootwait"  # Ensure reboot doesn't hang on mounts
    mount mount_dir do
      device "#{host}:#{share}"
      fstype mount_type
      options mount_options
      action [:mount, :enable]
    end
    # Create the blob dir on the mount location if it doesn't already exist
    directory blob_mount_dir do
      owner owner
      group group
      mode 0750
      recursive true
      action :create
    end
  end
end
