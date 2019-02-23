include_recipe 'plone_buildout::patches'
# The varnish dir should not generate i/o so we mount it as tmpfs
directory '/var/lib/varnish' do
  recursive true
  action :create
end

mount '/var/lib/varnish' do
  fstype 'tmpfs'
  options 'rw,size=256M'
  device 'tmpfs'
  action [:mount, :enable]
end

ephemeral = node[:opsworks_initial_setup] && node[:opsworks_initial_setup][:ephemeral_mount_point] || '/'
# The ephemeral storage is quite a bit faster than root for our cache file
directory ::File.join(ephemeral, '/varnish') do
  recursive true
  action :create
end

node.normal['varnish']['storage_file'] = ::File.join(ephemeral, 'varnish/varnish_storage.bin')

include_recipe "varnish"
if %x[sudo apt-cache policy varnish | grep -i Candidate:].match(/3\./)
  node.normal["varnish"]["vcl_source"] = "default.vcl.erb"
else
  node.normal["varnish"]["vcl_source"] = "default.vcl4.erb"
end
