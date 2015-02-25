app_name = node["plone_zeoserver"]["app_name"]
return if app_name.nil? || app_name.empty?

deploy = node[:deploy][app_name]
# Don't run configure if deploy hasn't been run
return if deploy.nil? || deploy.empty? || deploy[:deploy_to].nil? || deploy[:deploy_to].empty? || !::File.exists?(deploy[:deploy_to]) || !::File.exists?(::File.join(deploy[:deploy_to], "current"))
include_recipe "plone_buildout::zeoserver"

# Update deploy
deploy = node[:deploy][app_name]

buildout_configure do
  deploy_data deploy
  app_name app_name
end
