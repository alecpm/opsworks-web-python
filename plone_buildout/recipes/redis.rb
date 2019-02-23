package 'redis-server'

replace_or_add "Redis Listens on all addresses" do
    path "/etc/redis/redis.conf"
    pattern ".*bind 127\.0\.0\.1.*"
    line "bind 0.0.0.0"
end
