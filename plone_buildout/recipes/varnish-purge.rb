# Get purge url regexps from node
ban_urls = node["varnish_purge_urls"] || ['.\*']

ban_urls = [ban_urls] if !ban_urls.kind_of?(Array)
if node['pretend_ubuntu_version'] || (platform?('ubuntu') && node['platform_version'].to_f >= 16.04)
    ban_cmd = 'req.url ~'
else
    ban_cmd = 'ban.url'
end

ban_urls.each { |ban_url| execute "echo '#{ban_cmd} #{ban_url}' | varnishadm" }
