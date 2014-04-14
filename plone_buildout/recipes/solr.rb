# We deploy solr using the buildout since that does all the
# configuration magic for us
app_name = node["plone_solr"]["app_name"]
return if !app_name

# Replace deploy if nil
node.default[:deploy][app_name] = {} if !node[:deploy][app_name]
deploy = node[:deploy][app_name]

if deploy && deploy[:deploy_to]
  directory ::File.join(deploy[:deploy_to], "shared", "parts", "solr-download") do
    recursive true
    action :delete
  end
end

additional_config =""

additional_config << (deploy["buildout_additional_config"] || "")
additional_config << "[solr-host]" << "\n" << "host = #{node[:opsworks][:instance][:private_dns_name]}"
node.normal[:deploy][app_name]["buildout_additional_config"] = additional_config

extra_parts = ["solr-download", "solr-instance"]
node.normal[:deploy][app_name]["buildout_extends"] = ["cfg/base.cfg"].concat(deploy["buildout_extends"] || [])
extra_parts = extra_parts.concat(deploy["buildout_parts_to_include"] || [])
node.normal[:deploy][app_name]["buildout_parts_to_include"] = extra_parts

# Setup upstart job
node.normal[:deploy][app_name]["buildout_init_type"] = :upstart
node.normal[:deploy][app_name]["buildout_init_commands"] = [{'name' => 'solr', 'cmd' => 'bin/solr-instance', 'args' => 'fg'}]

node.normal[:deploy][app_name]["environment"] = {"PYTHON_EGG_CACHE" => ::File.join(deploy[:deploy_to], "shared", "eggs")}.update(deploy["environment"] || {})

# Enable recipe
node.normal[:deploy][app_name]["custom_type"] = "buildout"
