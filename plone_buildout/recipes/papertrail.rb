# Add any non-syslog log files to watchlist
watch_files = {}

if node.recipe?('supervisor::default')
    watch_files["/var/log/supervisor/supervisord.log"] = 'supervisor'
end

if node.recipe?('plone_buildout::instances-setup')
  app_name = node['plone_instances']['app_name']

  # celery related logs, this may be redundant if celery is configured
  # to log to rsyslog
  if node['plone_instances']['enable_celery']
    # add celery logs to papertrail watchlist
    watch_files["/var/log/supervisor/#{app_name}-celery-stdout.log"] = 'celery'
    watch_files["/var/log/supervisor/#{app_name}-celery-stderr.log"] = 'celery'
  end
  if node['plone_instances']['celerybeat']
    # add celery logs to papertrail watchlist
    watch_files["/var/log/supervisor/#{app_name}-celerybeat-stdout.log"] = 'celerybeat'
    watch_files["/var/log/supervisor/#{app_name}-celerybeat-stderr.log"] = 'celerybeat'
  end

  # All supervisor client logs, may be redundant with client rsyslog logs
  instances = (node[:opsworks][:instance][:backends].to_i * node["plone_instances"]["per_cpu"].to_f/8).ceil if (!node[:opsworks][:instance][:backends].nil? && !node[:opsworks][:instance][:backends].zero?)
  instances = (node[:cpu][:total].to_i * node["plone_instances"]["per_cpu"].to_f).ceil if (node[:opsworks][:instance][:backends].nil? || node[:opsworks][:instance][:backends].zero?)
  instances = 1 if instances < 1 || !instances
  1.upto(instances) do |n|
    part = "client#{n}"
    watch_files["/var/log/supervisor/#{app_name}-#{part}-stdout.log"] = part
    watch_files["/var/log/supervisor/#{app_name}-#{part}-stderr.log"] = part
  end
end   

# Solr logs, may be too much data since it includes queries
if node['plone_solr']['enable_papertrail'] && node.recipe?('plone_buildout::solr-setup')
  app_name = node['plone_solr']['app_name']
  solr_log = ::File.join(node[:deploy][app_name][:deploy_to], 
                         'current', 'log', 'solr.log')
  watch_files[solr_log] = 'solr'
end

if node.recipe?('plone_buildout::nginx')
  watch_files['/var/log/nginx/error.log'] = 'nginx'
end

if node.recipe?('redis::server')
  watch_files['/var/log/redis/redis-server.log'] = 'redis'
end

watch_files.update(node['papertrail']['watch_files'] || {})
node.normal['papertrail']['watch_files'] = watch_files

include_recipe 'papertrail'
