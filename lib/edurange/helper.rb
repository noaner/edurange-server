module Edurange
  # Define basic logging functions
  def ridley
    ridley_connection ||= Ridley.from_chef_config(Settings.knife_path, { ssl: { verify: false } } )
  end
  def debug(message)
    Edurange.logger.debug message
  end
  def info(message)
    Edurange.logger.info message
  end
  def warn(message)
    Edurange.logger.warn message
  end

  class Helper
    def self.dry_run
      AWS.stub!
      # Stub individual things required
    end
    def self.generate_ssh_keys_for(players)
      players.each do |player|
        `rm id_rsa id_rsa.pub 2>/dev/null`
        `ssh-keygen -t rsa -f id_rsa -q -N ''`
        priv_key = File.open('id_rsa', 'rb').read
        pub_key = File.open('id_rsa.pub', 'rb').read

        player["generated_pub"] = pub_key
        player["generated_priv"] = pub_key
      end
    end
  end
end

