require 'chef/provider'

class Chef
  class Provider
    class Deploy < Chef::Provider
      def enforce_ownership
        Chef::Log.warn("Deploy directory ownership change monkey-patched to noop by plone_buildout recipe")
      end
    end
  end
end
