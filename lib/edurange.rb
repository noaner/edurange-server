require "edurange/version"
require "edurange/parser"
require "edurange/puppet_master"
require "edurange/edu_machine"

module Edurange
  class Init
    def init
      our_ssh_key = get_our_ssh_key()

      certs = gen_client_ssl_cert()
      conf = generate_puppet_conf(certs[0])

      facts = facter_facts()
      write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)

      run(command)
    end
  end
end
