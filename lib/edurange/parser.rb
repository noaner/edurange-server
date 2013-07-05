module Edurange
  class Parser

    def self.facter_facts(uuid, services)
      # Generate facts based on config. These facts are referenced in puppet configuration manifests
      services = services.join(',')
      facter_conf = <<conf
uuid=#{uuid}
services=#{services}
conf
    end
    def self.parse_yaml(contents)
      nodes = []
      file = YAML.load(contents)

      key_pair = AWS::EC2::KeyPairCollection.new[Settings.ec2_key]

      block = file["VPC_Mask"]
      ec2 = AWS::EC2::Client.new

      vpc_request = ec2.create_vpc(cidr_block: block)
      vpc = AWS::EC2::VPC.new(vpc_id: vpc_request[:vpc][:vpc_id])
      igw_vpc = AWS::EC2::VPCCollection.new[vpc_request[:vpc][:vpc_id]]
      vpc_id = vpc.id[:vpc_id] # Because having vpc_id be a string would be crazy

      info "Created VPC #{vpc_id}"
      
      igw = ec2.create_internet_gateway

      igw = AWS::EC2::InternetGatewayCollection.new[igw[:internet_gateway][:internet_gateway_id]]
      igw_vpc.internet_gateway = igw
      
      sleep(6) # TODO loop and check vpc status

      info "Created IGW #{igw.id}"

      nodes = []
      players = []
      
      # Iterate through groups. Create list of users (For nat instance logins)
      file["Groups"].each do |group|
        name, users = group
        players.concat(users)
      end

      players.flatten!

      # Create Subnet for nat and IGW

      # Create Nat Subnet
      nat_subnet = vpc.subnets.create('10.0.128.0/28', vpc_id: vpc_id)
      nat_route_table = vpc.route_tables.create(vpc_id: vpc_id)
      nat_subnet.route_table = nat_route_table

      players = Helper.generate_ssh_keys_for players

      uuid = `uuidgen`.chomp
      facts = Edurange::Parser.facter_facts(uuid, [])

      nat_instance = Instance.new
      nat_instance.ami_id = 'ami-2e1bc047'
      nat_instance.name = "NAT Instance"
      nat_instance.subnet = nat_subnet
      nat_instance.users = players
      nat_instance.uuid = uuid
      nat_instance.facts = facts
      nat_instance.is_nat = true

      nat_instance.startup

      nodes.push nat_instance
      nat_aws_object = nat_instance.aws_object

      # Route NAT traffic to internet
      nat_route_table.create_route("0.0.0.0/0", { internet_gateway: igw} )

      igw_vpc.security_groups.first.authorize_ingress(:tcp, 0..64555)

      subnets = []

      file["Subnets"].each do |parsed_subnet|
        subnet_name, subnet_mask = parsed_subnet.first
        subnet = igw_vpc.subnets.create(subnet_mask, vpc_id: vpc_id)
        debug subnet
        subnet_id = subnet.id

        player_route_table = igw_vpc.route_tables.create(vpc_id: vpc_id)
        subnet.route_table = player_route_table

        player_route_table.create_route("0.0.0.0/0", { instance: nat_aws_object } )

        subnets.push subnet

        # Skip creating instances if the subnet has none defined
        next unless parsed_subnet.has_key? "Instances"

        instances_associated = parsed_subnet["Instances"]
        info "Created subnet #{subnet_name}, mask: #{subnet_mask}"
        info "Instances in subnet: #{instances_associated}"

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
          users = []
          if node[1].has_key? "Groups"
            node[1]["Groups"].each do |group|
              # Collect all users for each group name
              debug "Got group name #{group} in instance. Adding users #{file["Groups"].values_at group}"
              users.concat file["Groups"].values_at group
            end
          end
          users.flatten! # Should be fine, but for good measure...


          # Get all of the instance names
          instance_login_names = users.collect { |user| user["login"] }

          # Get all of the information required (ssh key, etc) from the players matching instance_login_names
          instance_players = []
          players.each do |player|
            instance_players.push player if instance_login_names.include? player["login"]
          end

          debug "Players in new instance: #{p instance_players}"


          if instances_associated.include? name
            # Create in current subnet

            ami_id = info["AMI_ID"]
            ip_address = info["IP_Address"]

            unless info["Groups"].nil?
              groups_associated = info["Groups"]
              groups = groups_associated.inject([]) do |total_groups, group_associated|
                group_contents = file["Groups"][group_associated]
                p group_contents
                total_groups.concat(group_contents.values) unless group_contents.nil?
              end
              puts "Got groups: "
              p groups
            end

            software = info["Software"]

            script = Edurange::Helper.startup_script

            uuid = `uuidgen`.chomp
            facts = Edurange::Parser.facter_facts(uuid, packages)

            instance = Instance.new
            instance.name = name
            instance.ip_address = ip_address
            instance.subnet = subnet
            instance.uuid = uuid
            instance.facts = facts
            instance.users = instance_players

            nodes.push instance.startup
          end
        end

        subnets.each do |parsed_subnet|
          puts parsed_subnet
          file["Network"].each do |link|
            link_name, subnets = link.first
            p link_name
            p subnets
          end
        end
      end
    end
  end
end
