module Edurange
  def pool
    @pool ||= Thread.pool(Settings.max_threads)
  end
  def dispatch
    @pool.process do
      yield
    end
  end
  def wait_for_jobs
    @pool.shutdown
  end
  # Define basic logging functions
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
    def self.generate_ssh_keys_for(players)
      players.each do |player|
        `rm id_rsa id_rsa.pub 2>/dev/null`
        `ssh-keygen -t rsa -f id_rsa -q -N ''`
        priv_key = File.open('id_rsa', 'rb').read
        pub_key = File.open('id_rsa.pub', 'rb').read

        player["generated_pub"] = pub_key.chomp
        player["generated_priv"] = priv_key.chomp
      end
    end
    def self.export_players(players)
      File.open('players.txt', 'w') do |file|
        players.each do |player|
          password = (0..6).map{ ('a'..'z').to_a[rand(26)] }.join
          file.puts "#{player['login']},#{password},#{player['generated_priv']}------ENDUSER------"
        end
      end
    end
    def self.export_nodes(nodes)
      File.open('nodes.txt', 'w') do |file|
        nodes.each do |node|
          name, info = node
          if info.has_key? "IP_Address"
            file.puts "#{info['IP_Address']}"
          end
        end
      end
    end
  end
end

