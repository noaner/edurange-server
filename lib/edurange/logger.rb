module Edurange
  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::WARN
  if Edurange::Settings.logger_level
    @@logger.level = Edurange::Settings.logger_level
  end
end
