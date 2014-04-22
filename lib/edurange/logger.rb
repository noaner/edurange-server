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

  log_file = File.open("#{Dir.getwd}/debug.log", "a")
  @@logger_file = Logger.new log_file
  @@logger_file.level = Logger::INFO

  @@logger = Logger.new STDOUT
  @@logger.level = Settings['logging_level'] ||= Logger::WARN
  def self.logger
    @@logger
  end
  def self.logger_file
    @@logger_file
  end
  def self.logger_level=(level)
    @@logger.level = level
  end
end
