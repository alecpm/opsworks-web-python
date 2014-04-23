#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: django-configure
#

node[:deploy].each do |application, deploy|
  if deploy["custom_type"] != 'django'
    next
  end

  if deploy[:deploy_to]
    django_configure do
      deploy_data deploy
      app_name application
    end
  end
end
