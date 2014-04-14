node[:deploy].each do |application, deploy|
  if deploy[:custom_type] != 'django'
    next
  end

  enable_gunicorn = Helpers.buildout_setting(deploy, 'enable_gunicorn', node)
    supervisor_service application do
      action [:stop, :disable]
    end
  end

end

include_recipe 'opsworks_deploy_python::python-undeploy'
