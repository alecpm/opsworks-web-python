#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: buildout
#
node[:deploy].each do |application, deploy|
  if deploy["custom_type"] != 'buildout'
    next
  end

  buildout_setup do
    deploy_data deploy
    app_name application
  end
  
  python_base_deploy do
    deploy_data deploy
    app_name application
  end
  
  buildout_configure do
    deploy_data deploy
    app_name application
    force_build deploy["always_build_on_deploy"]
  end
  
end
