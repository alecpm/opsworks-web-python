app_name =  node["plone_instances"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]
# Don't run if deploy hasn't been run, or there's no mr.developer
return if deploy.nil? || deploy.empty? || deploy[:deploy_to].nil? || deploy[:deploy_to].empty? || !::File.exists?(deploy[:deploy_to]) || !::File.exists?(::File.join(deploy[:deploy_to], 'current'))

develop_bin = ::File.join(deploy[:deploy_to], 'current', 'bin', 'develop')
execute "#{develop_bin} co -a '.*'" do
  user deploy[:user]
  group deploy[:group]
  cwd  ::File.join(deploy[:deploy_to], 'current')
  only_if 'test -e #{develop_bin}'
end

execute "#{develop_bin} up" do
  user deploy[:user]
  group deploy[:group]
  cwd ::File.join(deploy[:deploy_to], 'current')
  only_if "test -e #{develop_bin}"
end
