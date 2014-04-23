define :_django_celery_base do
  deploy = params[:deploy_data]
  application = params[:app_name]

  celery = deploy["django_celery"]
  # Create the config and link it into our package
  celery_config = template ::File.join(deploy[:deploy_to], "shared", "celeryconfig.py") do
    source "celeryconfig.py.erb"
    owner deploy[:user]
    group deploy[:group]
    mode 0644
    variables :broker => celery["broker"]
  end

  link ::File.join(deploy[:deploy_to], "current", celery["config_file"]) do
    link_type :symbolic
    to celery_config.path
    owner deploy[:user]
    group deploy[:group]
    mode 0644
  end

  # Enable events if the cam is on
  node.normal[:deploy][application]["django_celery"]["enable_events"] = true if celery["celerycam"]
end


define :django_djcelery do
  deploy = params[:deploy_data]
  application = params[:app_name]

  deploy = node[:deploy][application]

  _django_celery_base do
    deploy_data deploy
    app_name application
  end

  include_recipe 'supervisor'
  celery = deploy["django_celery"]
  cmds = {}
  if celery["queues"]
      cmds["celeryd"] = "celeryd -Q #{celery["queues"].join(',')} #{celery["enable_events"] ? "-E" : ""}"
  else
    cmds["celeryd"] = "celeryd #{celery["enable_events"] ? "-E" : ""}"
  end
  cmds["celerybeat"] = "celerybeat" if celery["celerybeat"]
  cmds["celerycam"] = "celerycam" if celery["celerycam"]

  cmds.each do |type, cmd|
    supervisor_service "#{application}-#{type}" do
      action :enable
      command "#{::File.join(deploy[:deploy_to], 'shared', 'env', 'bin', 'python')} manage.py #{cmd}"
      environment deploy["environment"]
      directory ::File.join(deploy[:deploy_to], "current")
      autostart true
      user deploy[:user]
      subscribes :restart, "template[#{::File.join(deploy[:deploy_to], "shared", "celeryconfig.py")}]", :delayed
      subscribes :restart, "template[#{::File.join(deploy[:deploy_to], 'current', Helpers.django_setting(deploy, 'settings_file', node))}]", :delayed
    end
  end
end

define :django_celery do
  deploy = params[:deploy_data]
  application = params[:app_name]

  include_recipe 'supervisor'
  celery = deploy["django_celery"]

  app_name = celery["app_name"]
  _django_celery_base do
    deploy_data deploy
    app_name application
  end

  cmds = {}
  cmds["celery"] = "worker"
  cmds["celerybeat"] = "beat" if celery["celerybeat"]
  cmds.each do |type, cmd|
    cmd = "#{cmd} -A #{app_name}" if app_name
    supervisor_service "#{application}-#{type}" do
      action :enable
      command "#{::File.join(deploy[:deploy_to], 'shared', 'env', 'bin', 'celery')} #{cmd}"
      environment deploy["environment"]
      directory ::File.join(deploy[:deploy_to], "current")
      autostart true
      user deploy[:user]
      subscribes :restart, "template[#{::File.join(deploy[:deploy_to], "shared", "celeryconfig.py")}]", :delayed
      subscribes :restart, "template[#{::File.join(deploy[:deploy_to], 'current', Helpers.django_setting(deploy, 'settings_file', node))}]", :delayed
    end
  end

end
