#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: django-configure
#

node[:deploy].each do |application, deploy|
  if deploy["custom_type"] != 'django'
    next
  end

  django_configure do
    deploy_data deploy
    app_name application
  end
end
