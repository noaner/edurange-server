module Edurange
  class PuppetMaster
    def get_our_ssh_key
      # make some ssh keys
      `ssh-keygen -t rsa -f /home/ubuntu/.ssh/id_rsa -N '' -q` unless File.exists?("/home/ubuntu/.ssh/id_rsa")
      # return our public key                                                                                                                                                                        
      file = File.open("/home/ubuntu/.ssh/id_rsa.pub", "rb")
      contents = file.read
    end

    def gen_client_ssl_cert
      # We need to:
      # Generate unique name (UUIDgen)
      uuid = `uuidgen`.chomp
      # Create cert for name on puppetmaster
      `sudo puppet cert --generate #{uuid}`
      ssl_cert = `sudo cat /var/lib/puppet/ssl/certs/#{uuid}.pem`.chomp
      ca_cert = `sudo cat /var/lib/puppet/ssl/certs/ca.pem`.chomp
      private_key = `sudo cat /var/lib/puppet/ssl/private_keys/#{uuid}.pem`.chomp
      return [uuid, ssl_cert, ca_cert, private_key]
    end
    def write_shell_config_file(ssh_key, puppetmaster_ip, certs, puppet_conf, facter_facts)
      File.open("my-user-script.sh", 'w') do |file|
        file_contents = <<contents
#!/bin/sh
set -e
set -x
echo "Hello World.  The time is now $(date -R)!" | tee /root/output.txt
apt-get update; apt-get upgrade -y

key='#{ssh_key.chomp}'
echo $key >> /home/ubuntu/.ssh/authorized_keys

echo #{puppetmaster_ip} puppet >> /etc/hosts
apt-get -y install puppet

mkdir -p /var/lib/puppet/ssl/certs
mkdir -p /var/lib/puppet/ssl/private_keys
mkdir -p /etc/puppet

mkdir -p /etc/facter/facts.d
echo '#{facter_facts}' >> "/etc/facter/facts.d/facts.txt"

echo '#{certs[1]}' >> "/var/lib/puppet/ssl/certs/#{certs[0]}.pem"
echo '#{certs[2]}' >> "/var/lib/puppet/ssl/certs/ca.pem"
echo '#{certs[3]}' >> "/var/lib/puppet/ssl/private_keys/#{certs[0]}.pem"

echo '#{puppet_conf.chomp}' > /etc/puppet/puppet.conf

sed -i /etc/default/puppet -e 's/START=no/START=yes/'
service puppet restart

echo "Goodbye World.  The time is now $(date -R)!" | tee /root/output.txt
contents
        file.write(file_contents)
      end
    end
  end
end
