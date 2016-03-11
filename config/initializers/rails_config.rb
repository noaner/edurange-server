Config.setup do |config|
  config.const_name = "Settings"
  Config.load_files(
    Rails.root.join("config", "settings.yml").to_s
  )
end
