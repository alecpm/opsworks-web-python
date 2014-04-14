# Pick defaults for export
if node[:opsworks] && node[:opsworks][:deploy_user]
  owner = node[:opsworks][:deploy_user][:user] || 'deploy'
  group = node[:opsworks][:deploy_user][:group] || 'www-data'
else
  owner = 'deploy'
  group = 'www-data'
end

network = node["plone_blobs"]["network"] || "#{node[:opsworks][:instance][:private_ip]}/8"

user owner do
  action :create
  comment "deploy user"
  uid next_free_uid
  gid group
  supports :manage_home => true
  not_if do
    existing_usernames = []
    Etc.passwd {|user| existing_usernames << user['name']}
    existing_usernames.include?(owner)
  end
end

# Enable NFS
include_recipe "nfs"
include_recipe "nfs::server"

export_base = node["plone_blobs"]["nfs_export_dir"]
blob_path = ::File.join(export_base, 'blobstorage')
tmp_path = ::File.join(export_base, 'tmp')

directory export_base do
  mode 0750
  owner owner
  group group
  recursive true
  action :create
end
directory blob_path do
  mode 0750
  owner owner
  group group
  action :create
end
directory tmp_path do
  mode 01777
  owner owner
  group group
  action :create
end

nfs_export export_base do
  network network
  writeable true
  options ['no_subtree_check', 'no_root_squash']
end
