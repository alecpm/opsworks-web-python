include_recipe "plone_buildout::instances"
app_name =  node["plone_instances"]["app_name"]
deploy = node[:deploy][app_name]

buildout_configure do
  deploy_data deploy
  app_name app_name
  run_action [:stop, :disable]
end

include_recipe 'opsworks_deploy_python::python-undeploy'
