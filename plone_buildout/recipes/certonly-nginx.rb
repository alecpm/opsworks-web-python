package 'certbot'
package 'python3-certbot-nginx'

options = {
    'nginx' => true,
    'config-dir' => node['certbot']['config_dir'],
    'work-dir' => node['certbot']['work_dir'],
    'logs-dir' => node['certbot']['logs_dir'],
    'server' => node['certbot']['server'],
    'staging' => node['certbot']['staging'],

    'email' => node['certbot_email'],
    'domains' =>  node['certbot_domains'].join(','),
    'agree-tos' => true,
    'non-interactive' => true,
}

options_array = options.map do |key, value|
    if value === true
      ["--#{key}"]
    elsif value === false || value.nil?
      []
    else
      ["--#{key}", value]
    end
end

execute "#{node['certbot']['bin']} certonly #{options_array.flatten.join(' ')}" do
    if node['certbot']['sandbox']['enabled']
      user node['certbot']['sandbox']['user']
    end
end
