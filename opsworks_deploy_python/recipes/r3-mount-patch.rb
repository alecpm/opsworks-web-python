#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: r3-mount-patch
#
if node[:opsworks][:instance][:instance_type].start_with?('r3.')
    fs_dev = '/dev/xvdb'
    execute "mkfs" do
        command "mkfs.ext4 -E nodiscard #{fs_dev}"
        not_if "blkid #{fs_dev} | grep TYPE=\"ext"
    end
    execute "mount all" do
        command "mount -a"
    end
end

# Re-run base setup recipes
loaded_recipes = run_context.instance_variable_get(:@loaded_recipes)
loaded_recipes.delete('opsworks_initial_setup::bind_mounts')
include_recipe "opsworks_initial_setup::bind_mounts"
