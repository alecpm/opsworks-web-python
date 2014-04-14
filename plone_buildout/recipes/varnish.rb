# The varnish dir should no generate i/o so we mount it as tmpfs
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

# The storage on /mnt is quite a bit faster than on / for our cache file
directory '/mnt/varnish' do
  recursive true
  action :create
end

node.normal["varnish"]["vcl_cookbook"] = "plone_buildout"
node.normal['varnish']['storage_file'] = "/mnt/varnish/varnish_storage.bin"

include_recipe "varnish"
