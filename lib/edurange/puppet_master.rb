module Edurange
  class PuppetMaster
    def self.puppetmaster_ip
      # Get external IP using in a way that works in any environment
      debug "Obtaining external ip"
      ip ||= `curl ifconfig.me 2>/dev/null`
    end
    def self.gen_client_ssl_cert(uuid)
      # This generates certificates so puppet can authenticate our client. The certs and such are passed through securely using EC2's API
      # Generates a UUID
      # Creates certificate using puppet
      # Read the cert auth file
      # Read the private key generated for client
      `sudo puppet cert --generate #{uuid}`
      ssl_cert = `sudo cat /var/lib/puppet/ssl/certs/#{uuid}.pem`.chomp
      ca_cert = `sudo cat /var/lib/puppet/ssl/certs/ca.pem`.chomp
      private_key = `sudo cat /var/lib/puppet/ssl/private_keys/#{uuid}.pem`.chomp
      return [ssl_cert, ca_cert, private_key]
    end
    def self.append_to_config(conf)
      File.open("my-user-script.sh", 'a+') do |file|
        file.write(conf)
      end
    end
    def self.write_puppet_conf(instance_id, conf)
      # Creates configuration specific to our newly created host. Stored in /etc/puppet/manifests/#{uuid}.pp
      File.open("#{ENV['HOME']}/edurange/derp.pp", "w") do |file|
        file.write(conf)
      end
      `sudo mv #{ENV['HOME']}/edurange/derp.pp /etc/puppet/manifests/#{instance_id}#{Time.now.to_s.gsub(' ','')}.pp`
    end
  end
end
