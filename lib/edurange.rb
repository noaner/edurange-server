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
        packages = node[4]
        puts "Preparing #{node_name} - Packages: #{packages} ami_id: #{ami_id}"
        certs = Edurange::PuppetMaster.gen_client_ssl_cert() 
        conf = Edurange::PuppetMaster.generate_puppet_conf(certs[0])
        facts = Edurange::Parser.facter_facts(certs[0], packages)
        Edurange::PuppetMaster.write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)
        machine = Edurange::EduMachine.new(certs[0], keyname, ami_id)
        p machine.spin_up()
      end
    end
  end
end
