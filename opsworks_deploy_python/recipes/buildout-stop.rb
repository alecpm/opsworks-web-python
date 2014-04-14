node[:deploy].each do |application, deploy|
  if deploy[:custom_type] != 'buildout'
    next
  end

  buildout_configure do
    deploy_data deploy
    app_name application
    run_action :stop
  end

end
