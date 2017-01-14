certbot_certonly_webroot 'multi-cert' do
  webroot_path '/var/www/certbot'
  email 'root@localhost'
  domains node['certbot_domains']
  expand true
  agree_tos true
end
