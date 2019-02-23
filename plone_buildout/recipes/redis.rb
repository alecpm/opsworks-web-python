package 'redis-server'

service 'redis-server'
    supports :restart => true, :status => true, :reload => false
    action :nothing
end

replace_or_add "Redis Listens on all addresses" do
    path "/etc/redis/redis.conf"
    pattern ".*bind 127\.0\.0\.1.*"
    line "bind 0.0.0.0"
    notifies :restart, 'service[redis-server]'
end
