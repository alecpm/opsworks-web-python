include_recipe "plone_buildout::zeoserver"
app_name = node["plone_zeoserver"]["app_name"]
return if !app_name
deploy = node[:deploy][app_name]

buildout_setup do
  deploy_data deploy
  app_name app_name
end
