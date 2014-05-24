# Get purge url regexps from node
ban_urls = node["varnish_purge_urls"] || ['.\*']

ban_urls = [ban_urls] if !ban_urls.kind_of?(Array)

ban_urls.each { |ban_url| execute "varnishadm ban.url #{ban_url}" }
