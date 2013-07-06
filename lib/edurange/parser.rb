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

      cloud = Cloud.new
      cloud.cidr_block = block

      # Iterate through groups. Create list of users (For nat instance logins)
      players = []
      file["Groups"].each do |group|
        name, users = group
        players.concat(users)
      end
      players.flatten!

      # Create Nat Subnet
      nat_subnet = Subnet.new
      nat_subnet.is_nat = true
      nat_subnet.cidr_block = '10.0.128.0/28'
      cloud.subnets << nat_subnet 

      players = Helper.generate_ssh_keys_for players

      uuid = `uuidgen`.chomp # TODO - replace with securerandom#uuid
      facts = Edurange::Parser.facter_facts(uuid, [])

      nat_instance = Instance.new
      nat_instance.ami_id = 'ami-2e1bc047'
      nat_instance.name = "NAT Instance"
      nat_instance.subnet = nat_subnet
      nat_instance.users = players
      nat_instance.uuid = uuid
      nat_instance.facts = facts
      nat_instance.is_nat = true

      nat_subnet.instances << nat_instance

      file["Subnets"].each do |parsed_subnet|
        subnet_name, subnet_mask = parsed_subnet.first
        subnet = igw_vpc.subnets.create(subnet_mask, vpc_id: vpc_id)
        debug "Created subnet: #{subnet}"
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

        puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip

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
      end
    end
  end
end
