module Edurange
  class Parser
    
    # Creates Puppet IPTables rules for required services
    # TODO: "something is buggy"
    #
    # ==== Attributes
    # * +uuid+ - Uses UUID of each specific instance to individually assign rules
    # * +rules+ - A list of IPTables rules to implement on the instance specified by +uuid+
    # 
    # === Example
    # * 

    def self.puppet_firewall_rules(uuid, rules)
      # This part isn't working - something is buggy. What it should do: (TODO)
      # Create puppet IPtables rules for each service required. Specific to instance (check based on UUID fact)
      puppet_rules = "if $uuid == '#{uuid}' {"
      rules.each do |rule|
        protocol = rule[0]
        port = rule[1]
        dest = (rule[2] == 'All') ? '0.0.0.0/24' : rule[2]

        puppet_rule = "iptables { '#{uuid} iptables: #{protocol}://#{dest}:#{port}':
        proto => '#{protocol}',
        dport => '#{port}',
        destination => '#{dest}
        }"

        puppet_rules += puppet_rule
      end
      puppet_rules += "\n}"
      puppet_rules

    end
    def self.facter_facts(uuid, services)
      # Generate facts based on config. These facts are referenced in puppet configuration manifests
      services = services.join(',')
      facter_conf = <<conf
uuid=#{uuid}
services=#{services}
conf
    end
    def self.parse_yaml(filename, keyname)
      nodes = []
      file = YAML.load_file(filename)

      key_pair = AWS::EC2::KeyPairCollection.new[keyname]

      block = file["VPC_Mask"]
      ec2 = AWS::EC2::Client.new

      vpc_request = ec2.create_vpc(cidr_block: block)
      vpc = AWS::EC2::VPC.new(vpc_id: vpc_request[:vpc][:vpc_id])
      vpc_id = vpc.id[:vpc_id] # Because having vpc.id return a string would be crazy
      
      puts "Created vpc: "
      p vpc

      sleep(6) # TODO loop and check vpc status

      nodes = []

      subnets = []
      file["Subnets"].each do |parsed_subnet|
        subnet_name, subnet_mask = parsed_subnet.first
        subnet = vpc.subnets.create(subnet_mask, vpc_id: vpc_id)
        subnet_id = subnet.id
        subnets.push subnet

        # Skip creating instances if the subnet has none defined
        next unless parsed_subnet.has_key? "Instances"

        instances_associated = parsed_subnet["Instances"]
        puts "Subnet: #{subnet_name}, mask: #{subnet_mask}"
        puts "Instances: #{instances_associated}"
        p subnet
        our_ssh_key = Edurange::PuppetMaster.get_our_ssh_key()
        puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip()

        file["Nodes"].each do |node|
          name, info = node

          node_software_groups = info["Software"]
          packages = []
          node_software_groups.each do |node_software_group|
            file["Software"].each do |software_definition|
              software, software_packages = software_definition
              software_packages = software_packages["Packages"]
              if node_software_groups.include? software
                packages.concat software_packages
              end
            end
          end
          if node[1].has_key? "Groups"
            users = node[1]["Groups"].collect do |group|
              file["Groups"].values_at group
            end
            users.flatten!
          else
            users = []
          end
          certs = Edurange::PuppetMaster.gen_client_ssl_cert()
          conf = Edurange::PuppetMaster.generate_puppet_conf(certs[0])
          facts = Edurange::Parser.facter_facts(certs[0], packages)
          Edurange::PuppetMaster.write_shell_config_file(our_ssh_key,puppetmaster_ip, certs, conf, facts)
          users_script = Edurange::Helper.users_to_bash(users)
          Edurange::PuppetMaster.append_to_config(users_script)

          
          if instances_associated.include? name

            # Create in current subnet

            ami_id = info["AMI_ID"]
            ip_address = info["IP_Address"]

            unless info["Groups"].nil?
              groups_associated = info["Groups"]
              groups = groups_associated.inject([]) do |total_groups, group_associated|
                group_contents = file["Groups"][group_associated]
                total_groups.concat(group_contents) unless group_contents.nil?
              end
              puts "Got groups: "
              p groups
            end

            software = info["Software"]

            script = Edurange::Helper.startup_script
            puts "Script: "
            puts script

            nodes.push Edurange::Instance.new(name, ami_id, ip_address, key_pair, script, subnet_id).startup
          end
        end
        puts nodes

        subnets.each do |parsed_subnet|
          puts "Yo subnet ACLS"
          puts parsed_subnet
          puts "Yo subnet"
          file["Network"].each do |link|
            link_name, subnets = link.first
          end
        end

      end
    end
  end
end
