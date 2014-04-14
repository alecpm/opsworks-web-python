define :buildout_download_caches do
  deploy = params[:deploy_data]

  archives = Helpers.buildout_setting(deploy, 'cache_archives', node) || []

  archives.each do |archive|

    url = archive["url"]
    location = ::File.join(deploy[:deploy_to], archive["path"])
    purge = archive["purge"]

    if purge
      directory location do
        recursive true
        action :delete
        end
    end

    directory location do
      mode 0750
      owner deploy[:user]
      group deploy[:group]
      recursive true
      action :create
      not_if "test -d #{location}"
    end

    # Only download the cache if the dir is empty
    if purge || Dir["#{location}/*"].empty?
      
      archive_url = URI.parse(url)
      fname = ::File.basename archive_url.path
      unless archive["user"].blank?
        archive_url.user = archive["user"]
        archive_url.password = archive["password"]
      end
      archive_url = archive_url.to_s
      
      if archive_url
        tmpdir = Dir.mktmpdir('download-caches')
        directory tmpdir do
          mode 0755
        end
        
        remote_file "#{tmpdir}/#{fname}" do
          source archive_url
          owner deploy[:user]
          group deploy[:group]
        end
        
        execute 'extract tarred cache' do
          cwd location
          user deploy[:user]
          group deploy[:group]
          command "tar xvfz #{tmpdir}/#{fname}"
        end
      end
    end
  end
end
