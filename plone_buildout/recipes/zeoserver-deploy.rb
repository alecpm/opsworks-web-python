include_recipe "plone_buildout::zeoserver"
app_name = node["plone_zeoserver"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]
return if deploy.nil? || deploy.empty? || deploy[:scm].nil? || deploy[:scm].empty?

python_base_deploy do
  deploy_data deploy
  app_name app_name
end

buildout_configure do
  deploy_data deploy
  app_name app_name
end
