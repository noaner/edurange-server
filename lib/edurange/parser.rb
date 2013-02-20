module Edurange
  class Parser
    def self.puppet_firewall_rules(uuid, rules)
      puppet_rules = ""
      rules.each do |rule|
        protocol = rule[0]
        port = rule[1]
        dest = (rule[2] == 'All') ? '0.0.0.0/24' : rule[2]

        puppet_rule = "iptables { '#{uuid} iptables: #{protocol}://#{dest}:#{port}':
        proto => '#{protocol}',
        dport => '#{port}',
        destination => '#{dest}
        }"

        p puppet_rule
        puppet_rules += puppet_rule
      end

    end
    def self.facter_facts(uuid, services)
      services = services.join(',')
      facter_conf = <<conf
uuid=#{uuid}
services=#{services}
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
