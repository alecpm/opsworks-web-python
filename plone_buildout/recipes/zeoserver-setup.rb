include_recipe "plone_buildout::zeoserver"
app_name = node["plone_zeoserver"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]

# Replace deploy if nil
node.default[:deploy][app_name] = {} if (node[:deploy][app_name].nil? || node[:deploy][app_name].empty?)
deploy = node[:deploy][app_name]

os_packages = ['libjpeg-dev', 'libpng-dev', 'libxml2-dev', 'libxslt-dev']

node.normal[:deploy][app_name]["os_packages"] = os_packages.concat(deploy["os_packages"] || [])
Chef::Log.debug("Merged os_packages for zeoserver: #{deploy["os_packages"]}")

buildout_setup do
  deploy_data deploy
  app_name app_name
end

if !deploy[:user].nil? && !node["plone_zeoserver"]["filestorage_dir"].nil?
  directory node["plone_zeoserver"]["filestorage_dir"] do
    owner deploy[:user]
    group deploy[:group]
    mode 0700
    recursive true
    action :create
    ignore_failure true
  end
end
if !deploy[:user].nil? && !node["plone_blobs"]["blob_dir"].nil?
  # Create the blob dir if it doesn't exist, and give it "safe" permissions
  directory node["plone_blobs"]["blob_dir"] do
    owner deploy[:user]
    group deploy[:group]
    mode 0700
    recursive true
    action :create
    ignore_failure true
  end
end
