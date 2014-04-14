include_recipe 'deploy'

node[:deploy].each do |application, deploy|
  virtualenv application + '-venv' do
    action :delete
  done
  directory "#{deploy[:deploy_to]}" do
    recursive true
    action :delete
    only_if do 
      ::File.exists?("#{deploy[:deploy_to]}")
    end
  end
end
