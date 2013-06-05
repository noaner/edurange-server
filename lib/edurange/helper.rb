module Edurange
  class Helper
    def self.startup_script(facts, groups)
      File.open('my-user-script.sh', 'rb').read
    end

  end
end

