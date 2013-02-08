module Edurange
  class Parser
    def self.facter_facts(uuid)
      facter_conf = <<conf
uuid=#{uuid}
services=apache,vsftpd,iptables
conf
    end
  end
end
