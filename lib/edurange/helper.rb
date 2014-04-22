module Edurange
  def self.progress_bar(total = 100)
    @@progress_bar ||= ProgressBar.create(format: '%a |%b>>%i| %p%% %t',
                                          starting_at: 0,
                                          total: total)
  end
  def self.add_progress
    Edurange.progress_bar.increment
  end
  def dispatch(&work)
    #Celluloid::Future.new &work
    yield
    #pool ||= Thread.pool(Settings.max_threads)
    #end
  end

  # Define basic logging functions
  def debug(message)
    Edurange.logger.debug message
    Edurange.logger_file.debug message
  end
  def info(message)
    Edurange.logger.info message
    Edurange.logger_file.info message
  end
  def warn(message)
    Edurange.logger.warn message
    Edurange.logger_file.warn message
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

