#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: django
#

node[:deploy].each do |application, deploy|
  if deploy["custom_type"] != 'django'
    next
  end

  django_setup do
    deploy_data deploy
    app_name application
  end

  # We don't want to run migrations before updating config files
  migrate = deploy[:migrate]
  node.override[:deploy][application][:migrate] = false
  deploy = node[:deploy][application]
  python_base_deploy do
    deploy_data deploy
    app_name application
  end
  # Back to normal
  node.override[:deploy][application][:migrate] = migrate
  deploy = node[:deploy][application]

  # install requirements
  requirements = Helpers.django_setting(deploy, 'requirements', node)
  if requirements
    Chef::Log.info("Installing using requirements file: #{requirements}")
    pip_cmd = ::File.join(deploy["venv"], 'bin', 'pip')
    execute "#{pip_cmd} install --source=#{Dir.tmpdir} -r #{::File.join(deploy[:deploy_to], 'current', requirements)}" do
      cwd ::File.join(deploy[:deploy_to], 'current')
      user deploy[:user]
      group deploy[:group]
      environment 'HOME' => ::File.join(deploy[:deploy_to], 'shared')
    end
  else
    Chef::Log.debug("No requirements file found")
  end

  django_configure do
    deploy_data deploy
    app_name application
    run_action [] # Don't run actions here
  end
  
  # Migration
  if deploy["migrate"] && deploy["migration_command"]
      migration_command = "#{::File.join(deploy["venv"], "bin", "python")} #{deploy["migration_command"]}"
    execute migration_command do
      cwd ::File.join(deploy[:deploy_to], 'current')
      user deploy[:user]
      group deploy[:group]
    end
  end

  # collect static resources
  if deploy["django_collect_static"]
    cmd = deploy["django_collect_static"].is_a?(String) ? deploy["django_collect_static"] : "collectstatic --noinput"
    execute "#{::File.join(node[:deploy][application]["venv"], "bin", "python")} manage.py #{cmd}" do
      cwd ::File.join(deploy[:deploy_to], 'current')
      user deploy[:user]
      group deploy[:group]
    end
  end
end
