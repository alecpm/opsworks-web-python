# Meant to be run on an app's Deploy event
# to configure HTTPS server and certificate

include_recipe 'nginx::service'

application_name = node['plone_instances']['app_name']
application = node[:deploy][application_name]

# Only run if the app being deployed is the primary app
return if node['certbot_domains'].empty? && (application.nil? || !application[:ssl_certificate])

if !node['certbot_domains'].empty? || application[:domains]
  base_path = node['plone_instances']['site_id']
  # Set default domain
  vhosts = {'_' => base_path}

  # Set certbot key name based on first registered certbot hostname
  key_name = node['certbot_domains'][0] unless node['certbot_domains'].empty?

  # Virtualhosts for all defined subsites
  if node['plone_instances']['subsites']
    node['plone_instances']['subsites'].each {
      |domain, path| vhosts[domain] = base_path + '/' + path
    }
  end

  # Virtualhosts for all non-wildcard certbot domains that aren't already defined,
  # probably unnecessary
  if node['certbot_domains']
    node['certbot_domains'].each do |domain|
      vhosts[domain] = base_path unless (vhosts.has_key?(domain) || domain.start_with?('*.'))
    end
  end

  # Virtualhosts for all non-wildcard AWS app domains that aren't already defined,
  # also probably unnecessary
  if application[:domains]
    application[:domains].each do |domain|
      vhosts[domain] = base_path unless (vhosts.has_key?(domain) || domain.start_with?('*.'))
    end
  end

  template "#{node[:nginx][:dir]}/sites-available/instances-ssl" do
    source 'instances-ssl.nginx.erb'
    owner 'root'
    group 'root'
    mode 0644
    variables(
      application: application,
      domains: vhosts,
      key_name: key_name
    )
    notifies :restart, 'service[nginx]', :delayed
  end

  link "#{node[:nginx][:dir]}/sites-enabled/instances-ssl" do
    to "#{node[:nginx][:dir]}/sites-available/instances-ssl"
    owner 'root'
    group 'root'
    mode 0644
  end

end

if application[:ssl_support]
  # certificate

  directory "#{node[:nginx][:dir]}/ssl" do
    action :create
    owner 'root'
    group 'root'
    mode 0600
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.crt" do
    cookbook 'nginx'
    mode '0600'
    source 'ssl.key.erb'
    variables key: application[:ssl_certificate]
    notifies :restart, 'service[nginx]'
    only_if do
      application[:ssl_support]
    end
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.key" do
    cookbook 'nginx'
    mode '0600'
    source 'ssl.key.erb'
    variables key: application[:ssl_certificate_key]
    notifies :restart, 'service[nginx]'
    only_if do
      application[:ssl_support]
    end
  end

  template "#{node[:nginx][:dir]}/ssl/#{application[:domains].first}.ca" do
    cookbook 'nginx'
    mode '0600'
    source 'ssl.key.erb'
    variables key: application[:ssl_certificate_ca]
    notifies :restart, 'service[nginx]'
    only_if do
      application[:ssl_support] && application[:ssl_certificate_ca]
    end
  end

end
