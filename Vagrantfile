unless Vagrant.has_plugin?("berkshelf")
  raise 'vagrant-berkshelf is not installed, use "vagrant plugin install vagrant-berkshelf --plugin-version 2.0.0.rc3" to install it'
end

# Depends on installed precise64
# "vagrant box add precise64 http://files.vagrantup.com/precise64.box"
Vagrant.configure("2") do |config|
  config.vm.box = "precise64"
  config.berkshelf.enabled = true
  # Update Chef if needed
  config.vm.provision :shell, :inline => 'if [[ `chef-solo --version` != *11.10* ]]; then apt-get install python-software-properties --no-upgrade --yes; add-apt-repository ppa:brightbox/ruby-ng-experimental; apt-get update; apt-get install build-essential bash-completion ruby2.0 ruby2.0-dev --no-upgrade --yes; gem2.0 install chef --version 11.10.0 --no-rdoc --no-ri --conservative; fi'
  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = "."
    chef.add_recipe("plone_buildout::example")
    chef.json = {}
  end
  config.vm.network :forwarded_port, guest: 80, host: 12080
end
