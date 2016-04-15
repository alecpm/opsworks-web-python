exports = node["plone_blobs"]["gluster_export_dir"]
# We can put the GlusterFS configuration on our exports directory
# (since it's presumably a persistent EBS mount).
if node["plone_blobs"]["gluster_store_config_in_exports"]
  # Create the config dir if it doesn't already exist
  gluster_configuration = ::File.join(exports, 'gluster-config','glusterd')
  directory gluster_configuration do
    mode 0755
    recursive true
    action :create
  end
  # Bind mount it onto the real glusterd configuration area
  directory '/var/lib/glusterd' do
    mode 0755
    recursive true
    action :create
  end
  mount '/var/lib/glusterd' do
    device gluster_configuration
    fstype 'none'
    options "bind,rw"
    action [:mount, :enable]
  end
end
node.normal[:glusterfs][:server][:export_directory] = exports
volumes = {"blobs" => ::File.join(exports, "brick")}
# Install the packages, start the service and create the dirs, even if we haven't started
include_recipe "glusterfs::peer"

node.normal[:glusterfs][:server][:volumes] = volumes

gluster_layer = node["plone_blobs"]["layer"]
peers = node["plone_blobs"]["servers"]
if (peers.nil? || peers.empty?) && node[:opsworks] && node[:opsworks][:layers] && node[:opsworks][:layers][gluster_layer] && node[:opsworks][:layers][gluster_layer][:instances]
  peers = []
  node[:opsworks][:layers][gluster_layer][:instances].each {
    |name, instance| peers.push(instance[:private_ip])
  }
end

# Make sure the current instance is included as a peer, even if it's not fully booted
instance_host =  node[:opsworks][:instance][:private_ip]
peers << instance_host if !peers.include? instance_host

# Only perform server operations on first/existing layer member
return if peers[0] != instance_host

# Replicate across all peers (we don't want to deal with reconstructing partial snapshots)
node.normal[:glusterfs][:server][:replica] = peers.length if peers.length > 1
node.normal[:glusterfs][:server][:peers] = peers

# This sets up server and client.  There's a race condition here if
# you start two gluster servers at the same time, don't do that.
include_recipe "glusterfs::default"

# Handle newly added gluster servers by adding their exports as replica bricks
node[:glusterfs][:server][:volumes].each do |volume, brick|
  # If the volume is already up and there are bricks not in it, add them
  missing_bricks = ""
  if system("gluster volume info #{volume} | grep 'Status: Started'")
    # Performance optimization
    execute "gluster volume set #{volume} performance.cache-size 256MB"
    peers.each() do |peer|
      brick_id = "#{peer}:#{brick}"
      missing_bricks << " #{brick_id}" if !system("gluster volume info #{volume} | grep '#{brick_id}'")
    end
    replica = "replica #{node[:glusterfs][:server][:replica]}" if node[:glusterfs][:server][:replica]
    if !missing_bricks.empty?
      # Don't fail if the command fails
      execute "gluster volume add-brick #{volume} #{replica} #{missing_bricks} && gluster volume heal #{volume}" do
        returns [0, 1, 2, 255]
      end
    end
  end
end

# TODO: Prune replica bricks/peers which are no longer in the layer,
# requires parsing output of "gluster volume info" command and running
# "gluster volume remove-brick #{volume} replica #{n} #{brick}" and
# "gluster peer detach #{peer}" or better a "gluster volume replace-brick"
