require "edurange/version"
require "edurange/parser"
require "edurange/puppet_master"
require "edurange/edu_machine"

module Edurange
  class Init
    def self.init
      keyname = "newkey"
      ami_id = "ami-e720ad8e"
      our_ssh_key = Edurange::PuppetMaster.get_our_ssh_key()
      puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip()

      # do this each VM
      certs = Edurange::PuppetMaster.gen_client_ssl_cert() 
      conf = Edurange::PuppetMaster.generate_puppet_conf(certs[0])

      facts = Edurange::Parser.facter_facts()
      Edurange::PuppetMaster.write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)


      machine = Edurange::EduMachine.new(certs[0], keyname, ami_id)
      p machine.spin_up()
    end
  end
end
