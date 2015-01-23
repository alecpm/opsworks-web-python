default["deploy_buildout"] = {}
# Override these in an app deployment with node[:deploy][#{app_name}]["buildout_"#{varname}]
default["deploy_buildout"]["cache_archives"] = [] # mapping with references to cached archives to download {"url" => ..., "user" => ..., "password" => ..., "path" => ..., "purge" => ...}
default["deploy_buildout"]["symlink_before_migrate"] = {
  'eggs'=> 'eggs', 
  'downloads' => 'downloads',
  'extends' => 'extends',
  'var' => 'var',
  'parts' => 'parts',
# src should only be moved to shared for buildouts that use mr.developer exclusively
#  'src' => 'src',
}
default["deploy_buildout"]["purge_before_symlink"] = ['var', 'eggs', 'downloads', 'extends', 'parts']
default["deploy_buildout"]["create_dirs_before_symlink"] = ['var', 'eggs', 'downloads', 'extends', 'parts']
default["deploy_buildout"]["buildout_version"] = ""
default["deploy_buildout"]["bootstrap_params"] = ""
default["deploy_buildout"]["config"] = "deploy.cfg"
default["deploy_buildout"]["config_template"] = "deploy.cfg.erb"
default["deploy_buildout"]["extends"] = ['buildout.cfg']
default["deploy_buildout"]["config_cookbook"] = nil
default["deploy_buildout"]["flags"] = ''
default["deploy_buildout"]["supervisor_part"] = nil
default["deploy_buildout"]["inherit_parts"] = true
default["deploy_buildout"]["parts_to_include"] = []
default["deploy_buildout"]["additional_config"] = ''
default["deploy_buildout"]["debug"] = false
default["deploy_buildout"]["init_commands"] = []
default["deploy_buildout"]["init_type"] = "supervisor"
