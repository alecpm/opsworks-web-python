opsworks_deploy_python Cookbook
=============================
This cookbook is designed to be able to describe and deploy python applications on AWS OpsWorks, specifically Django and zc.buildout-based applications.

Note that this cookbook provides the Python-specific extensions for the `deploy` cookbook from opsworks-cookbooks.


Requirements
------------
Chef 0.10.0 or higher required (for Chef environment use).

The following Opscode cookbooks are dependencies:

- python
- gunicorn

Additionally, the AWS OpsWorks following cookbooks are required:

- deploy
- scm_helper


Recipes
-------------------

### python
The python deploy recipe creates a virtualenv and installs specified OS and python packages.  This is the default recipe.  These attributes can be set on the deploy configuration (`node[:deploy][application_name]`) or globally (`node["deploy_python"]`).

#### Attribute Parameters
- symlinks_before_migrate: Hash of shared_dir_file => current_dir_file represnting symlinks to create (passed into deploy recipe)
- purge_before_symlink: Array of directories in the repository to delete before creating symlinks
- create_dirs_before_symlink: Array of directories in the repository to create before symlinking
- packages: a list of python packages to be installed in the virtualenv
- os_packages: a list of OS packages to be installed on the instance
- venv_options: a string with command line options for virtualenv creation (defaults to `--no-site-packages`)
- python_major_version: the major version of python to use (only allowable in the deploy configuration, not globally), allows you to use python `2.4`, `2.5` or `2.6` as needed.

#### Related recipes
- python-undeploy: removes the virtual env


### buildout

The `buildout` recipe sets up, deploys and configures a zc.buildout project from an SCM repository.  It is based on the python deploy recipe and uses a virtualenv and accepts all python deploy attributes.  The attribute node[:deploy][appname][:custom_type] must be set to 'buildout' for this recipe to apply.

#### Attribute Parameters
- cache_archives: An array of hashes describing cache archives to download and extract.  Each element is a hash with the following keys:
  - url
  - user
  - password
  - path (path relative to the deploy location where the archive should be extracted)
  - purge (whether to remove the data and fetch it anew on every deploy or retain it)
- config: the name of the buildout config file to run.  Defaults to `deploy.cfg`
- config_template: the name template used to generate the config above.
- config_cookbook: the cookbook from which to lookup the above template
- flags: Command line flags to pass to the buildout command (e.g. '-No')
- extends: An array of the configuration files in the repository that the above config extends
- supervisor_part: The name of the `supervisor` buildout part, if any.  This will be added to system init
- inherit_parts: A flag determining whether to inherit the parts specified in the orig_cfg
- parts_to_include: A list of additional part names to enable in the buildout config
- additional_config: A string with additional buildout configuration
- debug: A flag to indicate whether the to run the instances in debug mode, not used in the default template
- init_commands: An array of commands to have the system supervisor manage, each element is a hash with the following entries:
  - cmd (the command, e.g. 'bin/instance')
  - args (any arguments to be passed, e.g. "console" for `:supervisor` or "start" for `:upstart`)
  - init_type: A symbol representing how the service is managed, currently either `:supervisor` or `:upstart`
  - delay: A delay in seconds, the command will only be started/restarted after waiting this amount of time (useful for rolling restarts of multiple services running on an instance).
- always_build_on_deploy: A flag that determines whether buildout will be run on every deploy, even if the repository and the config did not change.  This defaults to false, but should be set to true for buildouts which use mr.developer or similar to update sources during a buildout run. This should only be set on node[:deploy][application_name] and is not prefixed with `buildout_`.

All of these attributes are set globally in node[:deploy_buildout], but they also can be read on an application specific basis prefixed by `buildout_` as node[:deploy][application_name]['buildout_#{attribute}']

#### Related recipes
- buildout-setup: Runs setup commands needed to support application before deployment (to be run at instance start; `setup` in OpsWorks)
- buildout-deploy: Runs deploy, configuration and buildout if needed for the application (to be run at application deploy; `deploy` in OpsWorks)
- buildout-configure: Updates configuration files and runs buildout only if they have changed (to be run when new instances are started in a cluster or for any other reason a server might need to be re-configured; `configure` in OpsWorks)
- buildout-undeploy: Stops and disables the supervisor (if enabled) and removes the buildout/virtualenv
- buildout-start: Start the supervisor if enabled
- buildout-restart: Restart the supervisor if enabled
- buildout-stop: Stop the supervisor if enabled


### django
The `django` recipe deploys django projects from an SCM repository.  It is based on the python deploy recipe and uses a virtualenv.  The attribute node[:deploy][appname][:custom_type] must be set to 'django' for this recipe to apply.

#### Attribute Parameters
- settings_template: The name of the template to use for settings
- settings_file: The path to the settings file generated from the template above
- settings_cookbook: The cookbook in which to find the template above
- collect_static: A flag indicating whether the Django app collects static resources
- requirements: The path to the requirements file for the app
- database: A hash of the database connection info with the following attributes as needed:
  - adapter
  - host
  - port
  - name
  - username
  - password
- debug: Enable debug mode in the app
- gunicorn: Contains data about running the gunicorn server via supervisor, with the following flags
  - enabled
  - host: IP to bind to
  - port
  - backlog
  - workers
  - worker_class (sync|eventlet|gevent|tornado)
  - max_requests
  - timeout
  - keepalive
  - preload_app
  - environment

  All of these attributes are set globally in node[:deploy_django], but they also can be read on an application specific basis prefixed by `buildout_` as `node[:deploy][application_name]['django_#{attribute}']`.

The following are genera deploy related attributes to be set on `node[:deploy][application_name]` without a prefix:

- migrate: A boolean indicating whether migrations should be run
- migration_command: a command to be executed for database migrations


#### Related recipes
- django-setup: Runs setup commands needed to support application before deployment (to be run at instance start; `setup` in OpsWorks)
- django-deploy: Runs deploy, configuration and migrations if needed for the application (to be run at application deploy; `deploy` in OpsWorks)
- django-configure: Updates configuration scripts and restarts services if changed (to be run when new instances are started in a cluster or for any other reason a server might need to be re-configured; `configure` in OpsWorks)
- django-undeploy: Stops and disables the sewrver (if enabled) and removes the virtualenv
- django-start: Start the service if enabled
- django-restart: Restart the service if enabled
- django-stop: Stop the service if enabled


Usage
-----
A sample application application that builds the Plone 5.0 coredev buildout


```
run_list *%w[
  recipe[opsworks_deploy_python::buildout]
]

default_attributes({
  'deploy' => {
    'example_buildout' => {
                       'repository' => 'https://github.com/plone/buildout.coredev.git',
                       'revision' => '5.0'
                       },
               }
})
```

License & Authors
-----------------
- Author:: Alec Mitchell (<alecpm@gmail.com>)

With thanks to Jazkarta, Inc. and KCRW Radio
```text
Copyright 2014, Alec Mitchell

Licensed under the BSD License.
```
