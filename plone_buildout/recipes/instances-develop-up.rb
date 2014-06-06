app_name =  node["plone_instances"]["app_name"]
return if !app_name
deploy = node[:deploy][app_name]
# Don't run if deploy hasn't been run, or there's no mr.developer
return if !deploy || deploy.empty? || !deploy[:deploy_to] || !::File.exists?(deploy[:deploy_to]) || !::File.exists?(::File.join(deploy[:deploy_to], 'current'))

develop_cmd =::File.join(deploy[:deploy_to], 'current', 'bin', 'develop')
execute "#{develop_cmd} up" do
  user deploy[:user]
  group deploy[:group]
  cwd ::File.join(deploy[:deploy_to], 'current')
  only_if "test -e #{develop_cmd}"
end
