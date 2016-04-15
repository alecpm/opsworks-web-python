include_recipe "plone_buildout::solr"
app_name = node["plone_solr"]["app_name"]
return if app_name.nil? || app_name.empty?
deploy = node[:deploy][app_name]
return if deploy.nil? || deploy.empty? || deploy[:scm].nil? || deploy[:scm].empty?

python_base_deploy do
  deploy_data deploy
  app_name app_name
end

buildout_configure do
  deploy_data deploy
  app_name app_name
end

# Link for solr log rotation
directory ::File.join(deploy[:deploy_to], 'shared', 'log') do
  action :delete
  recursive true
  only_if "test -d #{::File.join(deploy[:deploy_to], 'shared', 'log')}"
end

link ::File.join(deploy[:deploy_to], 'shared', 'log') do
  action :delete
  only_if "test -l #{::File.join(deploy[:deploy_to], 'shared', 'log')}"
end

link ::File.join(deploy[:deploy_to], 'shared', 'log') do
  to ::File.join(deploy[:deploy_to], 'shared', 'parts', 'solr-instance', 'logs')
  action :create
end
