app_name = node["plone_zeoserver"]["app_name"]
return if app_name.nil? || app_name.empty?

# Replace deploy if nil
node.default[:deploy][app_name] = {} if (node[:deploy][app_name].nil? || node[:deploy][app_name].empty?)
deploy = node[:deploy][app_name]
extra_parts = ["zeoserver", "backup"]

if node["plone_zeoserver"]["enable_backup"]
  extra_parts.concat(["backupcronjob"])
end
if node["plone_zeoserver"]["enable_pack"]
  extra_parts.concat(["packcronjob"])
end

# Override here
node.normal[:deploy][app_name]["buildout_extends"] = ["cfg/base.cfg"].concat(deploy["buildout_extends"] || [])
extra_parts = extra_parts.concat(deploy["buildout_parts_to_include"] || [])
node.normal[:deploy][app_name]["buildout_parts_to_include"] = extra_parts

additional_config = ''

# Allow for custom blob dir (perhaps NFS or an EBS mount at a different location)
if node["plone_blobs"]["blob_dir"]
  blob_dir = node["plone_blobs"]["blob_dir"]
  additional_config << "\n[zeoserver]\nblob-storage = #{blob_dir}"
end
# Add rsyslog logging if desired
if node['plone_zeoserver']['syslog_facility'] && ::File.exists?('/dev/log')
  additional_config << "\n[zeoserver]" if !additional_config.start_with?('[zeoserver]')
  additional_config << "\nzeo-log-custom =\n    "
  additional_config << "<logfile>\n      "
  additional_config << "path ${buildout:directory}/var/log/${:_buildout_section_name_}.log\n      level INFO\n    </logfile>\n    "
  additional_config << "<syslog>\n      address /dev/log\n      "
  additional_config << "facility #{node['plone_zeoserver']['syslog_facility']}\n      "
  additional_config << "format ${:_buildout_section_name_}: %(message)s\n      "
  additional_config << "level #{node['plone_zeoserver']['syslog_level']}\n    </syslog>\n"
end

node.normal[:deploy][app_name]["buildout_additional_config"] = additional_config + (node[:deploy][app_name]["buildout_additional_config"] || '')


environment = {"PYTHON_EGG_CACHE" => ::File.join(node[:deploy][app_name][:deploy_to], "shared", "eggs")}

node.normal[:deploy][app_name]["buildout_init_type"] = :supervisor if (deploy["buildout_init_type"].nil? || deploy["buildout_init_type"].empty?)
# Setup supervisor job
node.normal[:deploy][app_name]["buildout_init_commands"] = [{'name' => 'zeoserver', 'cmd' => 'bin/zeoserver', 'args' => 'fg'}]

# This is really a setup step, but setup may be to early to find the mount, in which case it is skipped and run again later during configure.
# Maybe you want to mount your zeoserver's blob dir via NFS (why?)
if node["plone_zeoserver"]["nfs_blobs"] || node["plone_zeoserver"]["gluster_blobs"]
  blob_mounts do
    deploy_data deploy
    use_gluster node["plone_zeoserver"]["gluster_blobs"]
  end
elsif node["plone_blobs"]["blob_dir"]
  # Create the blob dir if it doesn't exist, and give it "safe" permissions
  directory node["plone_blobs"]["blob_dir"] do
    owner deploy[:user]
    group deploy[:group]
    mode 0700
    recursive true
    action :create
    ignore_failure true
  end
  blob_location = ::File.join(deploy[:deploy_to], 'shared', 'var', 'blobstorage')
  if node["plone_blobs"]["blob_dir"] != blob_location
    directory ::File.join(deploy[:deploy_to], 'shared', 'var') do
      owner deploy[:user]
      group deploy[:group]
      mode 0755
      recursive true
      action :create
      ignore_failure true
    end
    link blob_location do
      to node["plone_blobs"]["blob_dir"]
    end
  end
end

if (node["plone_zeoserver"]["filestorage_dir"]
  node["plone_zeoserver"]["filestorage_dir"] !=
  ::File.join(deploy[:deploy_to], 'shared', 'var', 'filestorage'))

  fs_dir = node["plone_zeoserver"]["filestorage_dir"]
  directory fs_dir do
    owner deploy[:user]
    group deploy[:group]
    mode 0700
    recursive true
    action :create
    ignore_failure true
  end
  directory ::File.join(deploy[:deploy_to], 'shared', 'var') do
    owner deploy[:user]
    group deploy[:group]
    mode 0700
    recursive true
    action :create
    ignore_failure true
  end
  link ::File.join(deploy[:deploy_to], 'shared', 'var', 'filestorage') do
    to fs_dir
  end
end

node.normal[:deploy][app_name]["environment"] = environment.update(deploy["environment"] || {})

# Enable recipe
node.normal[:deploy][app_name]["custom_type"] = "buildout"
