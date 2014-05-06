RailsConfig.setup do |config|
  config.const_name = "Settings"
  RailsConfig.load_files(
    Rails.root.join("config", "settings.yml").to_s
  )
end
