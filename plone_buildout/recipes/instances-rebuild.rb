app_name =  node["plone_instances"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]
# Don't run configure if deploy hasn't been run
return if deploy.nil? || deploy.empty? || deploy[:deploy_to].nil? || deploy[:deploy_to].empty? || !::File.exists?(deploy[:deploy_to]) || !::File.exists?(::File.join(deploy[:deploy_to], "current"))
include_recipe "plone_buildout::instances"

# Update deploy
deploy = node[:deploy][app_name]

develop_bin = ::File.join(deploy[:deploy_to], 'current', 'bin', 'develop')
if ::File.exist?(develop_bin)
  execute "#{develop_bin} co -a '.*'" do
    user deploy[:user]
    group deploy[:group]
    cwd  ::File.join(deploy[:deploy_to], 'current')
    only_if 'test -e #{develop_bin}'
  end
end

buildout_configure do
  deploy_data deploy
  app_name app_name
  force_build true
end
