require 'mkmf'
require 'open-uri'

define :python_base_setup do
  deploy = params[:deploy_data]
  application = params[:app_name]

  group = deploy[:group] || 'www-data'
  owner = deploy[:user] || 'deploy'

  Chef::Log.debug("*****************************************")
  Chef::Log.debug("Running #{recipe_name} for #{application}")
  Chef::Log.debug("*****************************************")

  os_packages = deploy["os_packages"] ? deploy["os_packages"] : node["deploy_python"]["os_packages"]
  # Install os dependencies
    os_packages.each do |pkg,ver|
    package pkg do
      action :install
      version ver if ver && ver.length > 0
    end
  end

  ruby_gems = deploy["ruby_gems"] ? deploy["ruby_gems"] : node["deploy_python"]["ruby_gems"]
  # Install gem dependencies
    ruby_gems.each do |pkg,ver|
    gem_package pkg do
      action :install
      version ver if ver && ver.length > 0
    end
  end

  # We need to establish a value for the original pip/venv location as
  # a baseline so we don't find the older ones later, we assume ubuntu
  # here, because we are lazy and this is for OpsWorks
  node.normal['python']['pip_location'] = "/usr/local/bin/pip"
  node.normal['python']['virtualenv_location'] = "/usr/local/bin/virtualenv"
  # We also need to override the prior override
  node.override['python']['pip_location'] = "/usr/local/bin/pip"
  node.override['python']['virtualenv_location'] = "/usr/local/bin/virtualenv"
  include_recipe "python::default"

  py_version = deploy["python_major_version"]
  use_custom_py = py_version && py_version != "2.7"
  py_version = py_version.to_s
  pip_location = find_executable "pip#{py_version}"
  virtualenv_location = find_executable "virtualenv-#{py_version}"
  virtualenv_ver_map = {
    "2.4" => "1.7.2",
    "2.5" => "1.9.1",
    "2.6" => "1.11.4"
  }
  if !pip_location && use_custom_py
    # We need to install an older python
    py_command = "python#{py_version}"
    apt_repository 'deadsnakes' do
      uri 'http://ppa.launchpad.net/fkrull/deadsnakes/ubuntu'
      distribution node['lsb'] && node['lsb']['codename'] || 'precise'
      components ['main']
      keyserver "keyserver.ubuntu.com"
      key "DB82666C"
      action :add
    end
    package "#{py_command}-dev"
    package "#{py_command}-setuptools" do
      action :install
      ignore_failure true  # This one doesn't always exist
    end
    package "#{py_command}-distribute-deadsnakes" do
      action :install
      ignore_failure true  # This one doesn't always exist
    end
    download = open("https://bootstrap.pypa.io/pip/#{py_version}/get-pip.py")
    IO.copy_stream(download, '/tmp/get-pip.py')
    execute "/usr/bin/#{py_command} /tmp/get-pip.py"
    pip_location = find_executable "pip#{py_version}"
  end

  venv_ver = virtualenv_ver_map[py_version]
  if use_custom_py
    python_pip "Install virtualenv" do
      package_name 'virtualenv'
      version venv_ver
      action :upgrade
    end
    virtualenv_location = find_executable "virtualenv-#{py_version}"
  end

  if use_custom_py
    # only set the python binary for this chef run, once the venv is
    # established we don't want to keep this around
    node.force_override['python']['binary'] = "/usr/bin/#{py_command}"
    node.override['python']['pip_location'] = pip_location
    node.override['python']['virtualenv_location'] = virtualenv_location
  else
    python_pip "setuptools" do
      version "26.1.1"
      action :upgrade
    end
  end

  # Set deployment user home dir, OpsWorks normally does this
  if !deploy[:home]
    node.default[:deploy][application][:home] = ::File.join('/home/', deploy[:user])
  end

  opsworks_deploy_user do
    deploy_data deploy
  end

  directory "#{deploy[:deploy_to]}/shared" do
    group group
    owner owner
    mode 0770
    action :create
    recursive true
  end

  # Setup venv
  venv_options = deploy["venv_options"] || node["deploy_python"]["venv_options"]
  venv_path = ::File.join(deploy[:deploy_to], "shared", "env")
  node.normal[:deploy][application]["venv"] = venv_path
  python_virtualenv "#{application}-venv" do
    path venv_path
    owner owner
    group group
    options venv_options
    action :create
  end

  packages = deploy["packages"] ? deploy["packages"] : node["deploy_python"]["packages"]
  # Install pip dependencies
  packages.each do |name, ver|
    python_pip name do
      version ver if ver && ver.length > 0
      virtualenv venv_path
      user deploy[:user]
      group deploy[:group]
      action :install
    end
  end
end

define :python_base_deploy do
  deploy = params[:deploy_data]
  application = params[:app_name]

  group = deploy[:group] || 'www-data'
  owner = deploy[:user] || 'deploy'

  # Merge symlink values from node default definitions
  ['symlink_before_migrate', 'purge_before_symlink', 'create_dirs_before_symlink'].each do |attr|
    if node["deploy_#{deploy[:custom_type]}"] && node["deploy_#{deploy[:custom_type]}"][attr]
      begin
        values = {}
        values.update(node["deploy_python"][attr] || {})
        values.update(node["deploy_#{deploy[:custom_type]}"][attr] || {})
        values.update(node[:deploy][application][attr] || {})
      rescue
        values = []
        values.concat(node["deploy_python"][attr] || [])
        values.concat(node["deploy_#{deploy[:custom_type]}"][attr] || [])
        values.concat(node[:deploy][application][attr] || [])
      end
      node.normal[:deploy][application][attr] = values
    end
  end

  # Opsworks deploy doesn't pass through :create_dirs_before_symlink,
  # so we need to take care of it ourselves
  (node[:deploy][application]["create_dirs_before_symlink"] || []).each do |dirname|
    directory ::File.join(deploy[:deploy_to], "shared", dirname) do
      owner owner
      group group
      mode 0750
      recursive true
      action :create
    end
  end

  if deploy[:scm]
    opsworks_deploy do
      deploy_data deploy
      app application
    end

    # Deploy recipe doesn't pass these through and we can only access the dirs after deployment
    (node[:deploy][application]["purge_before_symlink"] || []).each do |dirname|
      dir_path = ::File.join(deploy[:deploy_to], 'current', dirname)
      directory dir_path do
        recursive true
        action :delete
        only_if "test -d '#{dir_path}'"
      end
      # Now we create those links (possibly deleting them first to avoid deploy's duplicates)
      if node[:deploy][application]["symlink_before_migrate"].has_value?dirname
        shared_dirname = node[:deploy][application]["symlink_before_migrate"].key(dirname)
        shared_path = ::File.join(deploy[:deploy_to], 'shared',  shared_dirname)
        Chef::Log.debug("Relinking #{shared_path} and deleting stray link #{shared_path}/#{dirname}")
        link ::File.join(shared_path, dirname) do
          action :delete
        end
        link dir_path do
          link_type :symbolic
          to shared_path
          owner owner
          group group
          action [:delete, :create]
          only_if "test -e #{::File.join(deploy[:deploy_to], 'current')}"
        end
      end
    end

    node.set[:deploy][application]["initially_deployed"] = true
  else
    node.set[:deploy][application]["initially_deployed"] = false
    Chef::Log.error("Could not deploy app #{application} no SCM repository set")
  end

  # Setup venv
  venv_path = ::File.join(deploy[:deploy_to], 'shared', 'env')
  node.normal[:deploy][application]["venv"] = venv_path
  python_virtualenv application + '-venv' do
    path venv_path
    owner owner
    group group
    action :create
  end

  os_packages = deploy["os_packages"] ? deploy["os_packages"] : node["deploy_python"]["os_packages"]
  # Install os dependencies
  os_packages.each do |pkg,ver|
    package pkg do
      action :install
      version ver if ver && ver.length > 0
    end
  end

  packages = deploy["packages"] ? deploy["packages"] : node["deploy_python"]["packages"]
  # Install pip dependencies
  packages.each do |name, ver|
    python_pip name do
      version ver if ver && ver.length > 0
      virtualenv venv_path
      user owner
      group group
      action :install
    end
  end

  requirements_location = ::File.join(deploy[:deploy_to], 'current', 'requirements.txt')
  execute "Install Requirements" do
    user owner
    group group
    environment ({"HOME" => "/home/#{user}"})
    cwd ::File.join(deploy[:deploy_to], 'current')
    command "#{::File.join(venv_path, 'bin', 'pip')} install -r #{requirements_location}"
    only_if "test -e #{requirements_location}"
    ignore_failure true
  end

  release_path = ::File.join(deploy[:deploy_to], 'current')
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

end
