require "edurange/version"
require "edurange/parser"
require "edurange/puppet_master"
require "edurange/edu_machine"

module Edurange
  class Init
    def self.init(config_filename)
      keyname = "newkey"
      our_ssh_key = Edurange::PuppetMaster.get_our_ssh_key()
      puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip()

      nodes = Edurange::Parser.parse_yaml(config_filename) # format: nodes[node_name, ami_id, users, firewall_rules, packages]

      nodes.each do |node|
        node_name = node[0]
        ami_id = node[1]
        users = node[2]
        firewall_rules = node[3]
        packages = node[4]
        puts "Preparing #{node_name} - Packages: #{packages} ami_id: #{ami_id}"
        puts "Got users: #{users} and fw rules: #{firewall_rules}"
        certs = Edurange::PuppetMaster.gen_client_ssl_cert() 
        conf = Edurange::PuppetMaster.generate_puppet_conf(certs[0])
        facts = Edurange::Parser.facter_facts(certs[0], packages)
        Edurange::PuppetMaster.write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)

        users_script = self.users_to_bash(users)
        p users_script
        puts 'user_script above...'
        Edurange::PuppetMaster.append_to_config(users_script)

        

        machine = Edurange::EduMachine.new(certs[0], keyname, ami_id)
        #machine.users(users)
        
        machine_details = machine.spin_up()

        uuid = machine_details.uuid

        puppet_rules = Edurange::Parser.puppet_firewall_rules(uuid, firewall_rules)
        
        Edurange::PuppetMaster.write_puppet_conf(uuid, puppet_rules)
        p machine_details
      end
    end
    
    def self.users_to_bash(users)
      shell = ""
      users.each do |user|
        p user
        if user['password']
          #shell += "\n"
          #shell += "sudo useradd -m #{user[:login]}"
          #shell += ''
        elsif user['pass_file']
          #TODO implement pass files
          shell += "\n"
          shell += "sudo useradd -m #{user['login']} -s /bin/bash\n"
          shell += "sudo mkdir -p /home/#{user['login']}/.ssh\n"
          shell += "echo '#{user['pass_file']}' >> /home/#{user['login']}/.ssh/authorized_keys\n"
        end
      end
      shell
    end
  end
end
