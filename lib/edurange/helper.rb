module Edurange
  # Create global ec2 client, so we don't have to instantiate this everywhere (also helps with stubbing in future...)
  @@ec2 = AWS::EC2::Client.new

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
    def self.dry_run
      AWS.stub!
      # Stub individual things required
    end
    def self.puppet_setup_script(uuid)
      # Install / configure puppet. Should be fixed size and < 16kb for user-data max file requirement

      # Get SSL certs required to connect to PuppetMaster
      certs = Edurange::PuppetMaster.gen_client_ssl_cert(uuid)

      file_contents = <<contents
#!/bin/sh
set -e
set -x
echo "Hello World.  The time is now $(date -R)!" | tee /root/output.txt

killall dpkg || true
sleep 5
dpkg --configure -a

apt-get update; apt-get upgrade -y

echo #{PuppetMaster.puppetmaster_ip} puppet >> /etc/hosts
apt-get -y install puppet

mkdir -p /var/lib/puppet/ssl/certs
mkdir -p /var/lib/puppet/ssl/private_keys
mkdir -p /etc/puppet

echo '#{certs[0]}' >> "/var/lib/puppet/ssl/certs/#{uuid}.pem"
echo '#{certs[1]}' >> "/var/lib/puppet/ssl/certs/ca.pem"
echo '#{certs[2]}' >> "/var/lib/puppet/ssl/private_keys/#{uuid}.pem"

echo '#{PuppetMaster.generate_puppet_conf(uuid)}' > /etc/puppet/puppet.conf

sed -i /etc/default/puppet -e 's/START=no/START=yes/'
service puppet restart

echo "Goodbye World.  The time is now $(date -R)!" >> /root/output.txt
contents
    end
    
    def self.startup_script
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

