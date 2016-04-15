#
# Cookbook Name:: opsworks_deploy_python
# Recipe:: r3-mount-patch
#
if node[:opsworks][:instance][:instance_type].start_with?('r3.')
    fs_dev = '/dev/xvdb'
    execute "mkfs" do
        command "mkfs.ext4 -E nodiscard #{fs_dev}"
        not_if "blkid #{fs_dev} | grep TYPE=\\\"ext"
    end
    execute "umount all" do
        command "umount -a"
        ignore_failure true
    end
    execute "mount /mnt" do
        command "mount /mnt"
        ignore_failure true
    end
    for dir in ["/mnt/srv/www", node["plone_zeoserver"]["filestorage_dir"], node["plone_blobs"]["blob_dir"], node["plone_solr"]["data_dir"]]
        if !dir.nil? && !dir.empty? && !::File.exists?(dir)
            directory dir do
                user 'deploy'
                group 'www-data'
                mode 0700
                recursive true
                action :create
                ignore_failure true
            end
        end
    end
    execute "mount all" do
        command "mount -a"
        ignore_failure true
    end
    # Re-run base setup recipes
    loaded_recipes = run_context.instance_variable_get(:@loaded_recipes)
    loaded_recipes.delete('opsworks_initial_setup::bind_mounts')
    include_recipe "opsworks_initial_setup::bind_mounts"
    service "autofs" do
        action :restart
    end
end
