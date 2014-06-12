TODO
====

* Integrate with new RDS resource support in OpsWorks.

* Use newly provided search API to find and connect instances in
  various layers (we currently use the stack configuration directly).

* Provide some examples using data bags for configuration

* Native Solr support - use the OS packages to install Solr (instead
  of buildout and collective.recipe.solr) and allow custom
  configuration for use with alm.solrindex or collective.solr in the
  recipe.

* Automated rolling deployments.  We already have this implemented for
  Plone deployments, where the start/restart of each ZEO client on an
  instance can be delayed by a fixed amount.  It's not clear how to do
  this for multi-instance deployments where each instance runs single
  application server.  Would probably require running a script (boto?)
  external to OpsWorks to trigger a deployment on a single instance,
  monitor it for success and then trigger subsequent deployments.

* Integration of 3rd party (New Relic, Papertrail, ...) and internal
  (munin, ganglia, ...) monitoring services.

* Better documentation - we need feedback about what needs
  improvement.

* Instructions for using Docker to test custom recipes.

* Test suite?
