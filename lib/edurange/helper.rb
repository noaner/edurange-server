module Edurange
  def self.debug(message)
    puts "In debug!"
    Edurange.logger.debug message
  end
  def self.info(message)
    puts "In info!"
    Edurange.logger.info message
  end
  def self.warn(message)
    puts "In warn!"
    Edurange.logger.warn message
  end

  class Helper
    def self.startup_script
      `gzip < my-user-script.sh > my-user-script.sh.gz`
      File.open('my-user-script.sh.gz', 'rb').read
    end
    # Creates Bash lines to create user account and set password file or password given users
    #
    # ==== Attributes
    #
    # * +users+ - Takes parsed users
    # 
    def self.users_to_bash(users)
      puts "Got users in users to bash:"
      p users
      shell = ""
      users.each do |user|
        if user['password']
          shell += "\n"
          shell += "sudo useradd -m #{user['login']} -s /bin/bash\n"
          # Regex for alphanum only in password input
          shell += "echo #{user['login']}:#{user['password'].gsub(/[^a-zA-Z0-9]/, "")} | chpasswd\n" 
      # TODO - do something
        elsif user['pass_file']
          name = user['login']
          stuff = <<stuff
useradd -m #{name} -g admin -s /bin/bash
echo "#{name}:password" | chpasswd
mkdir -p /home/#{name}/.ssh

key='#{user['pass_file'].chomp}'
gen_pub='#{user["generated_pub"]}'
gen_priv='#{user["generated_priv"]}'

echo $gen_pub >> /home/#{name}/.ssh/authorized_keys
echo $gen_priv >> /home/#{name}/.ssh/id_rsa
echo $gen_pub >> /home/#{name}/.ssh/id_rsa.pub
chmod 600 /home/#{name}/.ssh/id_rsa
chmod 600 /home/#{name}/.ssh/authorized_keys
chmod 600 /home/#{name}/.ssh/id_rsa.pub
chown -R #{name} /home/#{name}/.ssh
stuff
          shell += stuff
        end
      end
      shell
    end
    def self.prep_nat_instance(players)
      # get nat instance ready
      data = <<data
#!/bin/sh
set -e
set -x
echo "Hello World.  The time is now $(date -R)!" | tee /root/output.txt
curl http://ccdc.boesen.me/edurange.txt > /etc/motd
data
  players.each do |player|
    `rm id_rsa id_rsa.pub`
    `ssh-keygen -t rsa -f id_rsa -q -N ''`
    priv_key = File.open('id_rsa', 'rb').read
    pub_key = File.open('id_rsa.pub', 'rb').read

    player["generated_pub"] = pub_key
    player["generated_priv"] = pub_key

    data += <<data
adduser -m #{player["login"]}
mkdir -p /home/#{player["login"]}/.ssh
echo '#{player["pass_file"]}' >> /home/#{player["login"]}/.ssh/authorized_keys
echo '#{priv_key}' >> /home/#{player["login"]}/.ssh/id_rsa
echo '#{pub_key}' >> /home/#{player["login"]}/.ssh/id_rsa.pub
chmod 600 /home/#{player["login"]}/.ssh/id_rsa
chmod 600 /home/#{player["login"]}/.ssh/authorized_keys
chmod 600 /home/#{player["login"]}/.ssh/id_rsa.pub
chown -R #{player["login"]} /home/#{player["login"]}/.ssh
data
      end
      File.open('nat_data', 'w') do |nat_data|
        nat_data.puts data
      end
      `gzip < nat_data > nat_data.gz`
      File.open('nat_data.gz', 'rb').read
    end

  end
end

