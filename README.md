Cookbooks for Deploying Python Web Applications on AWS OpsWorks
===============================================================

This repository contains cookbooks to assist with deploying python web
applications (specifically buildout based applications and Django
applications, along with some special helpers for deploying plone) on
AWS OpsWorks.  It uses OpsWorks Chef 11.10 and Berkshelf support to
pull in required cookbook dependencies.  See the included cookbooks
(`opsworks_deploy_python` and `plone_buildout`) for documentation on
their use.


Deploying with Your Own Cookbooks
---------------------------------

The simplest way to use these cookbooks as the basis for your own
cookbooks is to fork this repository and add your cookbook to it.

Ideally, you would be able to simply include the Berksfile from this
repo in your own custom cookbooks repostory and add the cookbooks to
it.  However, the AWS cookbooks these cookbooks depend on cannot be
easily resolved by Berkshelf.  I hope to find a better solution for
extending these cookbooks soon.


Testing your Deployments and Recipes Locally
--------------------------------------------

Depending on the complexity of your deployment, you may be able to
test your deployment and any custom recipes using `vagrant`, which has
built-in support for chef-solo and Berkshelf server provisioning.
There is an included example `Vagrantfile`, which demonstrates such an
example configuration.  The example Vagrantfile runs the example Plone
4.3 buildout and sets up mock layers to connect functionality.  You'll
need to modify the Berksfile when testing to explicitly pull in the
OpsWorks cookbook dependencies, by uncommenting the commented section
at the bottom.

You will need to install the vagrant-berkshelf plugin which requires
[ChefDK](http://getchef.com/downloads/chef-dk) to be installed, and
the ChefDK path (/opt/chefdk/bin) must be added at the front of your
PATH.  Then you must install the required vagrant ubuntu box and
plugins:

    export NOKOGIRI_USE_SYSTEM_LIBRARIES=true
    vagrant plugin install vagrant-berkshelf
    vagrant plugin install vagrant-vbguest

Install an appropriate virtual box:

    vagrant box add precise64 http://files.vagrantup.com/precise64.box

or

    vagrant box add ubuntu/trusty64

you will need to edit the Vagrantfile to point to the correct box.  Finally:

    vagrant up
