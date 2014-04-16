app_name = node["plone_zeoserver"]["app_name"]
return if !app_name

# Replace deploy if nil
node.default[:deploy][app_name] = {} if !node[:deploy][app_name]
deploy = node[:deploy][app_name]
extra_parts = ["zeoserver"]

if node["plone_zeoserver"]["enable_backup"]
  extra_parts.concat(["backup", "backupcronjob", "packcronjob"])
end
# Override here
node.normal[:deploy][app_name]["buildout_extends"] = ["cfg/base.cfg"].concat(deploy["buildout_extends"] || [])
extra_parts = extra_parts.concat(deploy["buildout_parts_to_include"] || [])
node.normal[:deploy][app_name]["buildout_parts_to_include"] = extra_parts

# Allow for custom blob dir (perhaps NFS or an EBS mount at a different location)
if node["plone_zeoserver"]["blob_dir"]
  blob_dir = node["plone_zeoserver"]["blob_dir"]
  node.normal[:deploy][app_name]["buildout_additional_config"] = "\n[zeoserver]\nblob-storage = #{blob_dir}"
else
  # Set the value to the buildout default for use in optional NFS mounting below
  blob_dir = ::File.join(node[:deploy][app_name][:deploy_to], "shared", "var", "blobstorage")
end

environment = {"PYTHON_EGG_CACHE" => ::File.join(node[:deploy][app_name][:deploy_to], "shared", "eggs")}

node.normal[:deploy][app_name]["buildout_init_type"] = :upstart if !deploy["buildout_init_type"]
# Setup upstart job
node.normal[:deploy][app_name]["buildout_init_commands"] = [{'name' => 'zeoserver', 'cmd' => 'bin/zeoserver', 'args' => 'fg'}]

# Maybe you want to mount your zeoserver's blob dir via NFS (why?)
if node["plone_zeoserver"]["nfs_blobs"] || node["plone_zeoserver"]["gluster_blobs"]
  blob_mounts do
    deploy_data deploy
    use_gluster node["plone_zeoserver"]["gluster_blobs"]
  end
elsif node["plone_blobs"]["blob_dir"]
  blob_location = ::File.join(deploy[:deploy_to], 'shared', 'var', 'blobstorage')
  if node["plone_blobs"]["blob_dir"] != blob_location
    directory ::File.join(deploy[:deploy_to], 'shared', 'var') do
      owner deploy[:user]
      group deploy[:group]
      mode 0755
      recursive true
      action :create
    end
    link blob_location do
      to node["plone_blobs"]["blob_dir"]
    end
  end
end

node.normal[:deploy][app_name]["environment"] = environment.update(deploy["environment"] || {})

# Enable recipe
node.normal[:deploy][app_name]["custom_type"] = "buildout"
