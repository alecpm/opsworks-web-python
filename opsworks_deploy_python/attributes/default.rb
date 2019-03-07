node.normal['pretend_ubuntu_version'] = nil
begin
    if File.readlines('/etc/lsb-release').grep(/pretending to be 14\.04/).size > 0
        node.normal['pretend_ubuntu_version'] = true
    end
rescue
    # ignore
end

if node.normal['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
    node.normal['supervisor']['dir'] = '/etc/supervisor/conf.d'
end

include_attribute "deploy"
include_attribute "opsworks_deploy_python::django"
include_attribute "opsworks_deploy_python::buildout"

node.default["deploy_python"]["custom_type"] = "python"
node.default["deploy_python"]["symlink_before_migrate"] = {}
node.default["deploy_python"]["purge_before_symlink"] = []
node.default["deploy_python"]["create_dirs_before_symlink"] = ['public', 'tmp']
node.default["deploy_python"]["packages"] = []
node.default["deploy_python"]["os_packages"] = []
node.default["deploy_python"]["ruby_gems"] = []
node.default["deploy_python"]["venv_options"] = '--no-site-packages'

node.default["apt"]["unattended_upgrades"]["enable"] = true
node.default["apt"]["unattended_upgrades"]["mail"] = nil
