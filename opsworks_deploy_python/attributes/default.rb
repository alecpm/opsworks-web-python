include_attribute "deploy"
include_attribute "opsworks_deploy_python::django"
include_attribute "opsworks_deploy_python::buildout"

node.default["deploy_python"]["custom_type"] = "python"
node.default["deploy_python"]["symlink_before_migrate"] = {}
node.default["deploy_python"]["purge_before_symlink"] = []
node.default["deploy_python"]["create_dirs_before_symlink"] = ['public', 'tmp']
node.default["deploy_python"]["packages"] = []
node.default["deploy_python"]["os_packages"] = []
node.default["deploy_python"]["venv_options"] = '--no-site-packages'
