instance_data = node["plone_instances"]
app_name = instance_data["app_name"]
return if !app_name

# Replace deploy if nil
node.default[:deploy][app_name] = {} if !node[:deploy][app_name]
deploy = node[:deploy][app_name]

os_packages = ['libjpeg-dev', 'libpng-dev', 'libxml2-dev', 'libxslt-dev']
if instance_data["enable_relstorage"]
  storage = instance_data["relstorage"]
  db = storage["db"]
  if storage["enable_cache"]
    # Add required packages for memcached support
    os_packages.push 'libmemcached-dev'
    case db["type"]
    when nil
      os_packages.push 'libpq-dev'
    when 'postgres'
      os_packages.push 'libpq-dev'
    when 'mysql'
      os_packages.push 'libmysqlclient-dev'
    end
  end
end

node.normal[:deploy][app_name]["os_packages"] = os_packages.concat(deploy["os_packages"] || [])
Chef::Log.debug("Merged os_packages for plone instances: #{deploy["os_packages"]}")

buildout_setup do
  deploy_data deploy
  app_name app_name
end
