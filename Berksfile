source 'https://supermarket.getchef.com'
# source 'http://cookbooks.opscode.com/api/v1/cookbooks'
# source 'https://api.berkshelf.com'

cookbook 'redis', github: 'coderanger/chef-redis', tag: '1.0.4'
cookbook 'glusterfs', github: 'alecpm/glusterfs-cookbook', tag: '0.2.0'
cookbook 'supervisor', github: 'poise/supervisor', ref: '2ebac961426eef394179c91a6cc9f9165a0f5e31'
cookbook 'papertrail', github: 'librato/papertrail-cookbook', tag: '0.0.6'
cookbook "traceview", github: 'Optaros/tracelytics-chef', ref: 'e0f1b2bd7b72956963626da2788c9cc6b2b90294'
cookbook 'newrelic_meetme_plugin', github: 'alecpm/newrelic_meetme_plugin'
cookbook 's3fs-fuse', github: 'alecpm/s3fs-fuse'

# We want to be explicit, since we don't explicitly include our
# packages, except when testing
cookbook 'varnish', '0.9.12'
cookbook 'gunicorn', '1.1.2'
cookbook 'build-essential', '1.4.2'
cookbook 'apt', '2.7.0'
cookbook 'yum', '3.1.2'
cookbook 'yum-epel', '0.3.4'
cookbook 'git', '3.1.0'
cookbook 'sqlite', '1.0.0'
cookbook 'ulimit', '0.3.2'
cookbook 'nfs', '1.0.0'
cookbook 'line', '~> 0.5.1'
cookbook 'postfix', '3.1.8'
cookbook 'python', '1.4.6'
cookbook 'runit', '1.5.10'
cookbook 'rsyslog', '1.12.2'
cookbook 'newrelic', '2.3.0'
cookbook 'newrelic_plugins', '1.1.0'
cookbook 'bluepill', '2.3.1'
cookbook 'certbot', '0.1.2'
# avoid certbot override
cookbook 'nginx', :github => "aws/opsworks-cookbooks", :rel => 'nginx', :tag => 'release-chef-11.10'

# Uncomment the items below for testing deployments with Vagrant

# def opsworks_cookbook(name)
#   cookbook name, { :github => "aws/opsworks-cookbooks", :rel => name, :tag => 'release-chef-11.10' }
# end

# cookbook 'opsworks_deploy_python', path: './opsworks_deploy_python'
# cookbook 'plone_buildout', path: './plone_buildout'
# opsworks_cookbook 'dependencies'
# opsworks_cookbook 'gem_support'
# opsworks_cookbook 'scm_helper'
# opsworks_cookbook 'ssh_users'
# opsworks_cookbook 'haproxy'
# opsworks_cookbook 'mod_php5_apache2'
# opsworks_cookbook 'opsworks_agent_monit'
# opsworks_cookbook 'opsworks_commons'
# opsworks_cookbook 'opsworks_initial_setup'
# opsworks_cookbook 'opsworks_java'
# opsworks_cookbook 'opsworks_nodejs'
# opsworks_cookbook 'opsworks_aws_flow_ruby'
# opsworks_cookbook 'deploy'
# opsworks_cookbook 'ssh_host_keys'
# opsworks_cookbook 'memcached'
# opsworks_cookbook 'mysql'
# opsworks_cookbook 'nginx'
# opsworks_cookbook 'apache2'
# opsworks_cookbook 'agent_version'
# opsworks_cookbook 'packages'
# opsworks_cookbook 'opsworks_rubygems'
# opsworks_cookbook 'opsworks_bundler'

# # opsworks_cookbook 'ruby'
# # opsworks_cookbook 'opsworks_cleanup'
# # opsworks_cookbook 'opsworks_custom_cookbooks'
# # opsworks_cookbook 'opsworks_ganglia'
# # opsworks_cookbook 'opsworks_shutdown'
# # opsworks_cookbook 'opsworks_stack_state_sync'
# # opsworks_cookbook 'passenger_apache2'
# # opsworks_cookbook 'php'
# # opsworks_cookbook 'rails'
# # opsworks_cookbook 'unicorn'
# # opsworks_cookbook 'ebs'
