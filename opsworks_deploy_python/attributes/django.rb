default["deploy_django"] = {}
# Override these in an app deployment with node[:deploy][#{app_name}]["django_"#{varname}]
default["deploy_django"]["settings_template"] = "settings.py.erb"
default["deploy_django"]["settings_file"] = "local_settings.py"
default["deploy_django"]["settings_cookbook"] = nil
default["deploy_django"]["collect_static"] = false
default["deploy_django"]["requirements"] = "requirements.txt"
default["deploy_django"]["legacy_db"] = false
default["deploy_django"]["database"] = {}
default["deploy_django"]["database"]["adapter"] = nil
default["deploy_django"]["database"]["name"] = nil
default["deploy_django"]["database"]["username"] = nil
default["deploy_django"]["database"]["password"] = nil
default["deploy_django"]["debug"] = false
default["deploy_django"]["migration_command"] = nil
default["deploy_django"]["gunicorn"] = {
  "enabled" => false,
  "host" => '0.0.0.0',
  "port" => 8080,
  "backlog" => 2048,
  "workers" => (node['cpu'] && node['cpu']['total']) && [node['cpu']['total'].to_i * 4, 8].min || 8,
  # Possible values 'sync', 'eventlet', 'gevent', 'tornado'
  "worker_class" => 'sync',
  "max_requests" => 0,
  "timeout" => 30,
  "keepalive" => 2,
  "preload_app" => false,
  "environment" => {}
}

default["deploy_django"]["celery"] = {
  "app_name" => nil,  # Name of django app module for celery to work on
  "enabled" => false,
  "djcelery" => false,
  "version" => nil,
  "results" => nil,
  "broker" => {
    "transport" => "amqplib",
    "host" => nil,
    "port" => nil,
    "user" => nil,
    "password" => nil,
    "vhost" => nil,
    "pool_limit" => nil,
    "connection_timeout" => nil,
    "connection_retry" => nil,
    "connection_mac_tries" => nil,
    "use_ssl" => nil
  },
  "config_file" => "celeryconfig.py",
  "enable_events" => false,
  "celerycam" => false,
  "celerybeat" => false,
  "queues" => nil # This should be an array of queue names if you want to enable queues
}
