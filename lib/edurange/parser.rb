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
      igw_vpc = AWS::EC2::VPCCollection.new[vpc_request[:vpc][:vpc_id]]
      vpc_id = vpc.id[:vpc_id] # Because having vpc.id return a string would be crazy
      
      igw = ec2.create_internet_gateway
      p igw
      igw = AWS::EC2::InternetGatewayCollection.new[igw[:internet_gateway][:internet_gateway_id]]
      p igw
      p vpc
      igw_vpc.internet_gateway = igw
      

      puts "Created vpc: "
      p vpc

      sleep(6) # TODO loop and check vpc status

      nodes = []

      subnets = []

      players = []
      file["Groups"].each do |group|
        name, users = group
        puts "Found users in group:"
        p users
        players.concat(users.values)
      end
      players.flatten!

      # Create Subnet for nat and IGW

      # Create Nat Subnet
      nat_subnet = vpc.subnets.create('10.0.128.0/28', vpc_id: vpc_id)
      nat_route_table = vpc.route_tables.create(vpc_id: vpc_id)
      nat_subnet.route_table = nat_route_table
      nat_instance = nat_subnet.instances.create(image_id: 'ami-2e1bc047', key_pair: key_pair, user_data: Edurange::Helper.prep_nat_instance(players))

      # Route NAT traffic to internet
      nat_route_table.create_route("0.0.0.0/0", { internet_gateway: igw} )

      puts "Waiting for NAT instance to spin up..."
      sleep(40)

      nat_instance.network_interfaces.first.source_dest_check = false
      nat_eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      nat_instance.associate_elastic_ip nat_eip

      igw_vpc.security_groups.first.authorize_ingress(:tcp, 0..64555)

      p nat_instance
      p nat_eip
      p nat_instance.elastic_ip

      file["Subnets"].each do |parsed_subnet|
        subnet_name, subnet_mask = parsed_subnet.first
        subnet = igw_vpc.subnets.create(subnet_mask, vpc_id: vpc_id)
        subnet_id = subnet.id

        player_route_table = igw_vpc.route_tables.create(vpc_id: vpc_id)
        subnet.route_table = player_route_table

        player_route_table.create_route("0.0.0.0/0", { instance: nat_instance } )

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
          Edurange::PuppetMaster.write_shell_config_file(puppetmaster_ip, certs, conf, facts)
          # get their internal ssh key from players
          instance_players = []

          instance_login_names = users.collect { |user| user["login"] }

          players.each do |player|
            instance_players.push player if instance_login_names.include? player["login"]
          end

          users_script = Edurange::Helper.users_to_bash(instance_players)
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
            puts "Got link:"
            p link_name
            puts "Got subnet:"
            p subnets
          end
        end

      end
    end
  end
end
