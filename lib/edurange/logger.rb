module Edurange

  # We now have a global logger (Edurange.logger) but there are shortcut methods debug, info, and warn that allows for logging various info without always cluttering output
  # If you set Settings.logging_level to 0, you will always get debug logging
  #
  # By default, only info/warn are displayed
  #
  # Usage:
  # debug "This is debug stuff!" 
  # info "Here's some info!"
  # warn "This is a warning"
  
  @@logger = Logger.new(STDOUT)
  Settings['logging_level'] ||= Logger::INFO
  @@logger.level = Settings['logging_level']
  def self.logger
    @@logger
  end
  def self.logger_level=(level)
    @@logger.level = level
  end
end
