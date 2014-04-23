# Cookbook Name:: opsworks_deploy_python
# Recipe:: buildout-rollback
#
node[:deploy].each do |application, deploy|
  if deploy["custom_type"] != 'django'
    next
  end

  deploy deploy[:deploy_to] do
    user deploy[:user]
    action 'rollback'
    only_if do
      File.exists?(deploy[:current_path])
    end
  end

  django_configure do
    deploy_data deploy
    app_name application
  end

end
