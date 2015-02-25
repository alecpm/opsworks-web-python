app_name = node["plone_solr"]["app_name"]
return if app_name.nil? || app_name.empty?
node.normal[:deploy][app_name]["os_packages"] = ["openjdk-7-jre-headless"].concat(node[:deploy][app_name]["os_packages"] || [])

deploy = node[:deploy][app_name]
include_recipe "plone_buildout::solr"

buildout_setup do
  deploy_data deploy
  app_name app_name
end
