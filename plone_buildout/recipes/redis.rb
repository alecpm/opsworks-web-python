include_recipe 'plone_buildout::patches'
package 'redis-server'

service 'redis-server' do
    supports :restart => true, :reload => false, :status => true
    action   :nothing
end

replace_or_add "Redis Listens on all addresses" do
    path "/etc/redis/redis.conf"
    pattern "^bind 127\.0\.0\.1.*"
    line "bind 0.0.0.0"
    notifies :restart, 'service[redis-server]'
end
