include_recipe "plone_buildout::zeoserver"
app_name = node["plone_zeoserver"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]

python_base_deploy do
  deploy_data deploy
  app_name app_name
end

buildout_configure do
  deploy_data deploy
  app_name app_name
end
