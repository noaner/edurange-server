module Edurange
  class Parser
    def self.facter_facts(uuid)
      facter_conf = <<conf
uuid=#{uuid}
services=apache2,vsftpd,iptables
conf
    end
    def self.parse_yaml(filename)
      nodes = []
      file = YAML.load_file(filename)

      softwares = {}
      file["Software"].each do |software|
        softwares[software[0]] = software[1]
      end

      groups = {}
      file["Groups"].each do |group|
        groups[group[0]] = group[1]
      end

      file["Nodes"].each do |node|
        node_name = node[0]
        ami_id = node[1]["AMI_ID"]

        users = []
        users_groups = node[1]["Users"]
        users_groups.each do |user_group|
          users.push groups[user_group]
        end
        users.flatten!

        software = []
        software_groups = node[1]["Software"]
        software_groups.each do |software_group|
          software.push softwares[software_group]
        end
        software.flatten!

        iptables_rules = []
        packages = []
        software.each do |sw|
          if !sw["IPTables"].nil?
            sw["IPTables"].each do |iptable_rule|
              port = iptable_rule[0]
              protocol = iptable_rule[1]["Protocol"]
              hosts = iptable_rule[1]["Hosts"]
              hosts.each do |host|
                iptables_rules.push [protocol, port, host]
              end
            end
          end
          if !sw["Packages"].nil?
            sw["Packages"].each do |package|
              packages.push package
            end
          end
        end
        nodes.push [
          node_name,
          ami_id,
          users,
          iptables_rules,
          packages
        ]
      end
      return nodes
    end
  end
end
