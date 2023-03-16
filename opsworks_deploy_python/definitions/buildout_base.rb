define :buildout_setup do
  deploy = params[:deploy_data]
  application = params[:app_name]

  python_base_setup do
    deploy_data deploy
    app_name application
  end

  buildout_download_caches do
    deploy_data deploy
  end

end


define :buildout_configure do
  deploy = params[:deploy_data]
  application = params[:app_name]
  run_actions = params[:run_action]
  force_build = params[:force_build]

  group = deploy[:group] || 'www-data'
  owner = deploy[:user] || 'deploy'

  buildout_download_caches do
    deploy_data deploy
  end

  # Setup symlink to enable automatic log rotation
  logs = "#{deploy[:deploy_to]}/shared/log"
  directory logs do
    recursive true
    action :delete
    only_if "test -d #{logs}"
  end
  link logs do
    link_type :symbolic
    to "#{deploy[:deploy_to]}/shared/var/log"
    owner owner
    group group
  end

  # Filter rails keys from environment and try to apply an ordering,
  # to avoid random changes to environment, which would mean random
  # changes to the configs and random service restarts
  env = deploy[:environment].select { |key, value| !key.match(/^(RUBY|RAILS|RACK)/) }
  env = Hash[*((env.sort_by { |key, value| key.to_s }).flatten)]
  node.normal[:deploy][application][:environment] = env

  # We only want to run this after the deploy has run, configure also
  # runs before deploy.  We need to check if the deploy has run by
  # checking for the deploy dir, but also checking a flag in case the
  # resources have been collected, but not created
  if deploy[:deploy_to] && (node[:deploy][application]["initially_deployed"] || ::File.exist?(deploy[:deploy_to]))
    release_path = ::File.join(deploy[:deploy_to], 'current')
    bootstrap_file = ::File.join(release_path, 'bootstrap.py')
    buildout_cmd = ::File.join(release_path, "bin", "buildout")
    venv_bin = ::File.join(deploy[:deploy_to], 'shared', 'env', 'bin')
    directory ::File.join(release_path, "bin") do
      owner owner
      group group
      only_if "test -e #{release_path} && test -e #{::File.join(venv_bin, 'buildout')}"
    end
    link buildout_cmd do
      link_type :symbolic
      to ::File.join(venv_bin, 'buildout')
      owner owner
      group group
      not_if "test -e #{buildout_cmd}"
      only_if "test -e #{release_path} && test -e #{::File.join(venv_bin, 'buildout')}"
    end
    config_file = Helpers.buildout_setting(deploy,'config', node)
    bootstrap_cmd = "#{::File.join(deploy[:deploy_to], 'shared', 'env', 'bin', 'python')} #{bootstrap_file} -c #{config_file}"
    build_cmd = "#{buildout_cmd} -c #{config_file} #{Helpers.buildout_setting(deploy, 'flags', node)}"
    buildout_version = Helpers.buildout_setting(deploy, 'buildout_version', node)
    if !(buildout_version.nil? || buildout_version.empty?)
      bootstrap_cmd = "#{bootstrap_cmd} --buildout-version=#{buildout_version}"
    end
    bootstrap_params = Helpers.buildout_setting(deploy,'bootstrap_params', node)
    if !(bootstrap_params.nil? || bootstrap_params.empty?)
      bootstrap_cmd = "#{bootstrap_cmd} #{bootstrap_params}"
    end
    services = []
    # Add our anticipated services (or supervisor) to upstart or supervisor
    init_commands = Helpers.buildout_setting(deploy, 'init_commands', node)
    init_type = Helpers.buildout_setting(deploy, 'init_type', node)
    if init_type == :supervisor
      if node.normal['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
        package 'supervisor'
      else
        include_recipe 'supervisor'
      end
    end

    env["PYTHON_EGG_CACHE"] = ::File.join(deploy[:deploy_to], 'shared', 'eggs')
    if !run_actions
      template ::File.join(release_path, config_file) do
        source Helpers.buildout_setting(deploy,'config_template', node)
        cookbook deploy["buildout_config_cookbook"] || 'opsworks_deploy_python'
        owner owner
        group group
        mode 0600

        variables Hash.new
        variables.update deploy # include any custom stuff in the deploy properties
        variables.update :extends => Helpers.buildout_setting(deploy, 'extends', node), :debug => Helpers.buildout_setting(deploy, 'debug', node), :supervisor_part => Helpers.buildout_setting(deploy, 'supervisor_part', node), :inherit_parts => Helpers.buildout_setting(deploy, 'inherit_parts', node), :parts_to_include => Helpers.buildout_setting(deploy, 'parts_to_include', node), :additional_config => Helpers.buildout_setting(deploy, 'additional_config', node)

        notifies :run, 'execute[bootstrap_buildout]', :immediately
        notifies :run, 'execute[run_buildout]', :immediately
      end

      # We define our commands for bootstrap and buildout, but don't run
      # them until we have a cfg change.
      # Bootstrap
      execute "bootstrap_buildout" do
        command "#{bootstrap_cmd}"
        user deploy[:user]
        group deploy[:group]
        cwd release_path
        environment env
        only_if "test -e #{::File.join(release_path, 'bootstrap.py')}"
        creates buildout_cmd
        notifies :run, 'execute[run_buildout]', :immediately
      end

      # Buildout run
      execute "run_buildout" do
        command "#{build_cmd}"
        user deploy[:user]
        group deploy[:group]
        cwd release_path
        environment env
        only_if "test -x #{buildout_cmd}"
        action force_build ? :run : :nothing
      end
    end

    # If the buildout has its own supervisor, just use that
    supervisor_part = Helpers.buildout_setting(deploy, 'supervisor_part', node)
    if supervisor_part
      template "/etc/init/supervisor.conf" do
        cookbook deploy["buildout_config_cookbook"] || 'opsworks_deploy_python'
        source "supervisor_upstart.erb"
        owner "root"
        group "root"
        mode 0700
        variables Hash.new
        variables.update deploy
        variables.update :supervisord => ::File.join(release_path, "bin", supervisor_part + 'd')
      end
      s = service "supervisor" do
        provider Chef::Provider::Service::Upstart
        action :enable
        subscribes :restart, "execute[run_buildout]", :delayed
        subscribes :restart, "template[/etc/init/supervisor.conf]", :delayed
      end
      services.push(s)
    elsif init_commands.length
      Chef::Log.info("init_commands: #{init_commands}")
      init_commands.each_with_index do |command, index|
        Chef::Log.info("init_command: #{command}")
        if command["name"] == application
          service_name = application
        elsif command["name"]
          service_name = "#{application}-#{command["name"]}"
        else
          service_name = "#{application}-#{index}"
        end
        case init_type.to_s
        when 'supervisor'
          s = supervisor_service service_name do
            command "#{::File.join(deploy[:deploy_to], "current", command["cmd"])} #{command["args"]}"
            user deploy[:user]
            environment env
            directory ::File.join(deploy[:deploy_to], "current")
            autostart true
            action :nothing
            if command['eventlistener']
              eventlistener true
              # need write permission to supervisor.sock
              user 'root'
            end
            if command['eventlistener_events']
              eventlistener_events command['eventlistener_events']
            end
            stdout_logfile "/var/log/supervisor/#{service_name}-stdout.log"
            stderr_logfile "/var/log/supervisor/#{service_name}-stderr.log"
            if command['delay'] && command['delay'] != 0
              # Only delay if the service is already running, only restart once
              only_if do
                run_count = node["start_count_#{service_name}"] || 0
                node.override["start_count_#{service_name}"] = run_count + 1
                status = Mixlib::ShellOut.new("supervisorctl status").run_command
                match = status.stdout.match("(^#{service_name}(\\:\\S+)?\\s*)([A-Z]+)(.+)")
                Chef::Log.info("Service #{service_name} status: #{match && match[3]}")
                if match && match[3] == 'RUNNING' && run_count == 1
                  Chef::Log.info("Delaying service #{service_name} by #{command['delay']} seconds")
                  sleep command['delay']
                  true
                elsif !match && run_count == 0
                  node.override["start_count_#{service_name}"] = 2
                  true
                elsif run_count <= 1
                  true
                else
                  false
                end
              end
            end
            subscribes :enable, "execute[run_buildout]", :delayed
            subscribes :restart, "execute[run_buildout]", :delayed
          end
          services.push(s)
        when 'upstart'
          service_conf = ::File.join("/etc/init", "#{service_name}.conf")
          template service_conf do
            cookbook deploy["buildout_config_cookbook"] || 'opsworks_deploy_python'
            owner "root"
            group "root"
            mode 0600
            source "upstart.conf.erb"
            variables Hash.new
            variables.update deploy
            variables.update :name => service_name, :script => ::File.join(deploy[:deploy_to], "current", command["cmd"]), :args => command["args"]
          end
          s = service service_name do
            provider Chef::Provider::Service::Upstart
            action :nothing
            if command['delay'] && command['delay'] != 0
              # Only delay if the service is already running, only restart once
              only_if do
                run_count = node["start_count_#{service_name}"] || 0
                node.override["start_count_#{service_name}"] = run_count + 1
                command = "/sbin/status #{service_name}"
                state = popen4(command) do |pid, stdin, stdout, stderr|
                  stdout.each_line do |line|
                    line =~ /\w+ \(?(\w+)\)?[\/ ](\w+)/
                    data = Regexp.last_match
                    return data[2]
                  end
                end
                Chef::Log.info("Service #{service_name} status: #{state}")
                if state == 'running' && run_count == 1
                  Chef::Log.info("Delaying service #{service_name} by #{command['delay']} seconds")
                  sleep command['delay']
                  true
                elsif !match && run_count == 0
                  node.override["start_count_#{service_name}"] = 2
                  true
                elsif run_count <= 1
                  true
                else
                  false
                end
              end
            end
            subscribes :enable, "execute[run_buildout]", :delayed
            subscribes :restart, "execute[run_buildout]", :delayed
            subscribes :enable, "template[#{service_conf}]", :delayed
            subscribes :restart, "template[#{service_conf}]", :delayed
          end
          services.push(s)
        end
      end
    end

    if run_actions
      run_actions = [run_actions] if !run_actions.kind_of?(Array)
      run_actions.each do |a|
        services.each { |s| s.run_action(a)}
      end
    end
  end
end
