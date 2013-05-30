require "edurange/version"
require "edurange/parser"
require "edurange/puppet_master"
require "edurange/edu_machine"

module Edurange
  class Init
    def self.init(config_filename)
      # Takes a configuration file
      # this is dependent on line number in config.yml (and not very readable), refactor TODO
      keyname = IO.readlines(File.expand_path('~/.edurange/config.yml'))[0].gsub("ec2_key:", "").strip
      # Get required info for generating config file
      our_ssh_key = Edurange::PuppetMaster.get_our_ssh_key()
      puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip()

      # Parse the configuration file, extract list of nodes
      nodes = Edurange::Parser.parse_yaml(config_filename) # format: nodes[node_name, ami_id, users, firewall_rules, packages]

      # For each node
      nodes.each do |node|
        # Extract vital information
        node_name = node[0]
        ami_id = node[1]
        users = node[2]
        firewall_rules = node[3]
        packages = node[4]

        puts "Preparing #{node_name} - Packages: #{packages} ami_id: #{ami_id}"
        # Generate ssl cert, puppet.conf, and Facter facts (based on config)
        certs = Edurange::PuppetMaster.gen_client_ssl_cert()
        conf = Edurange::PuppetMaster.generate_puppet_conf(certs[0])
        facts = Edurange::Parser.facter_facts(certs[0], packages)
        # Write a shell file that configures the client AMI
        Edurange::PuppetMaster.write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)

        # TODO messy
        # Adds users' accounts & pass files to bash config file
        users_script = self.users_to_bash(users)
        Edurange::PuppetMaster.append_to_config(users_script)


        # Create instance object
        machine = Edurange::EduMachine.new(certs[0], keyname, ami_id)

        # Start machine and parse output
        machine_details = machine.spin_up()

        # Get UUID
        uuid = machine_details.uuid

        # Apply instance specific IPtables rules
        puppet_rules = Edurange::Parser.puppet_firewall_rules(uuid, firewall_rules)

        # Write configuration file to puppetmaster location
        Edurange::PuppetMaster.write_puppet_conf(uuid, puppet_rules)
        p machine_details
      end
    end

    def self.users_to_bash(users)
      # Takes parsed users, creates bash lines to create user account and set password file or password
      shell = ""
      users.each do |user|
        if user['password']
          shell += "\n"
          shell += "sudo useradd -m #{user['login']} -s /bin/bash\n"
          shell += "echo #{user['login']}:#{user['password'].gsub(/[^a-zA-Z0-9]/, "")} | chpasswd\n" # Regex for alphanum only
 	  # TODO - do something
        elsif user['pass_file']
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
