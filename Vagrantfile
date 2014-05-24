unless Vagrant.has_plugin?("berkshelf")
  raise 'vagrant-berkshelf is not installed, use "vagrant plugin install vagrant-berkshelf --version 1.3.7" to install it'
end

# Depends on installed precise64
# "vagrant box add precise64 http://files.vagrantup.com/precise64.box"
Vagrant.configure("2") do |config|
  config.vm.box = "precise64"
  config.berkshelf.enabled = true
  # Allow installation of newer Rubies (AWS uses 2.0.0 now)
  config.vm.provision :shell, :inline =>  'apt-get update;  apt-get install python-software-properties --no-upgrade --yes; add-apt-repository ppa:brightbox/ruby-ng-experimental; apt-get update'
  # Update Chef if needed
  config.vm.provision :shell, :inline => 'if [[ `chef-solo --version` != *11.10* ]]; then apt-get install build-essential bash-completion ruby2.0 ruby2.0-dev --no-upgrade --yes; gem2.0 install chef --version 11.10.0 --no-rdoc --no-ri --conservative; fi'
  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = "."
    chef.add_recipe("plone_buildout::example")
    chef.json = {}
  end
  config.vm.network :forwarded_port, guest: 80, host: 12080
  config.vm.network :forwarded_port, guest: 8081, host: 12081
end
