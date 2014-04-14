package "wget"
package "xfsprogs"

gem_package "specific_install" do
  version "0.2.4"
end

execute "gem specific_install -l https://github.com/alecpm/ec2-snapshot.git"
execute "gem specific_install -l https://github.com/rightscale/right_http_connection.git -b 3359524d81cdfa9509e44959feceac0b52ac6a0c"

if node["ebs_snapshots"]["aws_key"]
  options = "--aws-region #{node[:opsworks][:instance][:region]}"
  options << " --aws-access-key #{node["ebs_snapshots"]["aws_key"]} --aws-secret-access-key #{node["ebs_snapshots"]["aws_secret"]} --skip-pending"

  if node["ebs_snapshots"]["keep"]
    options << " --keep-only #{node["ebs_snapshots"]["keep"]}"
  end

  cron "make_snapshots" do
    hour  node["ebs_snapshots"]["hour"]
    minute node["ebs_snapshots"]["minute"]
    weekday node["ebs_snapshots"]["weekday"]
    command "/usr/local/bin/ec2-snapshot #{options}"
    action :create
  end
end
