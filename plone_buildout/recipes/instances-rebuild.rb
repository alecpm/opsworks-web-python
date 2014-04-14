app_name =  node["plone_instances"]["app_name"]
return if !app_name
deploy = node[:deploy][app_name]
# Don't run configure if deploy hasn't been run
return if !deploy || deploy.empty? || !deploy[:deploy_to] || !::File.exists?(deploy[:deploy_to]) || !::File.exists?(::File.join(deploy[:deploy_to], "current"))
include_recipe "plone_buildout::instances"

# Update deploy
deploy = node[:deploy][app_name]

buildout_configure do
  deploy_data deploy
  app_name app_name
  force_build true
end
