# Meant to be run on an app's Deploy event
# to configure HTTPS server and certificate

include_recipe "nginx::service"

application_name = node["plone_instances"]["app_name"]
application = node[:deploy][application_name]

# Only run if the app being deployed is the primary app
return if node.default['certbot_domains'].empty? && (application.nil? || !application[:ssl_certificate] )

if application[:ssl_support] || !node.default['certbot_domains'].empty?

  template "#{node[:nginx][:dir]}/sites-available/instances-ssl" do
    source "instances-ssl.nginx.erb"
    owner "root"
    group "root"
    mode 0644
    variables(
      :application => application,
      :domains => !node.default['certbot_domains'].empty? ? node.default['certbot_domains'] : application[:domains]
    )
    notifies :restart, "service[nginx]", :delayed
  end

  link "#{node[:nginx][:dir]}/sites-enabled/instances-ssl" do
    to "#{node[:nginx][:dir]}/sites-available/instances-ssl"
    owner "root"
    group "root"
    mode 0644
  end

end

if application[:ssl_support]
  # certificate

  directory "#{node[:nginx][:dir]}/ssl" do
    action :create
    owner "root"
    group "root"
    mode 0600
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.crt" do
    cookbook 'nginx'
    mode '0600'
    source "ssl.key.erb"
    variables :key => application[:ssl_certificate]
    notifies :restart, "service[nginx]"
    only_if do
      application[:ssl_support]
    end
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.key" do
    cookbook 'nginx'
    mode '0600'
    source "ssl.key.erb"
    variables :key => application[:ssl_certificate_key]
    notifies :restart, "service[nginx]"
    only_if do
      application[:ssl_support]
    end
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.ca" do
    cookbook 'nginx'
    mode '0600'
    source "ssl.key.erb"
    variables :key => application[:ssl_certificate_ca]
    notifies :restart, "service[nginx]"
    only_if do
      application[:ssl_support] && application[:ssl_certificate_ca]
    end
  end

end
