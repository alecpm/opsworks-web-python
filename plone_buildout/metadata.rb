name             "plone_buildout"
maintainer       "Alec Mitchell"
maintainer_email "alecpm@gmail.com"
license          "BSD License"
description      "Recipes for a modular scalable deployment of Plone on AWS OpsWorks."
long_description  "This plone deployment recipe expects a modular buildout config structure with most parts defined in cfg/base.cfg, along with instance configuration in cfg/instances.cfg and relstorage instances in cfg/relstorage_instances.cfg.  It makes many assumptions about the buildout structure (clients are named client${n}, zeo port is hardcoded to 8001, etc.).  It supports ZEO or RelStorage deployments with separate DB and instance servers.  It supports Celery + Redis integration, Memcached integration with RelStorage, as well as Solr integration.  It supports automated backup and packing of ZEO servers and automated packing of RelStorage"
version          "0.0.1"


supports "ubuntu"
supports "amazon"

depends "opsworks_deploy_python"
depends "redis"
depends "nfs"
depends "varnish"
depends "nginx"
depends "haproxy"
depends "line"
depends "rsyslog"
depends "glusterfs"
depends "newrelic"
depends "newrelic_meetme_plugin"
depends "newrelic_plugins"
depends "papertrail"
depends "traceview"

# GlusterFS is missing this one
depends "apt"
