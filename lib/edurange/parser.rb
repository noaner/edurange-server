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
      cloud.add nat_subnet 

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

      nat_subnet.add nat_instance

      file["Subnets"].each do |parsed_subnet|
        subnet_name, subnet_mask = parsed_subnet.first

        subnet = Subnet.new
        subnet.cidr_block = subnet_mask
        cloud.add subnet 

        # Skip creating instances if the subnet has none defined
        next unless parsed_subnet.has_key? "Instances"

        instances_associated = parsed_subnet["Instances"]
        info "Created subnet #{subnet_name}, mask: #{subnet_mask}"
        info "Instances in subnet: #{instances_associated}"

        puppetmaster_ip = Edurange::PuppetMaster.puppetmaster_ip

        file["Nodes"].each do |node|
          name, info = node

          # Skip node if not in subnet
          next unless instances_associated.include? name

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
          if info.has_key? "Groups"
            info["Groups"].each do |group|
              # Collect all users for each group name
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

          instance_player_names = instance_players.collect { |player| player["login"] } # Should be identical to instance_players, but this tells us if there was a mismatch

          if instance_player_names != instance_login_names
            warn "Requested names (#{instance_player_names}) do _NOT_ all exist. #{instance_login_names}. Make sure you're referencing valid users in yaml."
          end

          debug "Players in instance #{name}: #{instance_player_names}"

          if instances_associated.include? name
            # Create in current subnet

            ami_id = info["AMI_ID"]
            ip_address = info["IP_Address"]

            unless info["Groups"].nil?
              groups_associated = info["Groups"]
              groups = groups_associated.inject([]) do |total_groups, group_associated|
                group_contents = file["Groups"][group_associated]
                total_groups.concat group_contents unless group_contents.nil?
              end
            end

            software = info["Software"]

            uuid = `uuidgen`.chomp
            facts = Edurange::Parser.facter_facts(uuid, packages)

            instance = Instance.new
            instance.name = name
            instance.ami_id = ami_id
            instance.ip_address = ip_address
            instance.subnet = subnet
            instance.uuid = uuid
            instance.facts = facts
            instance.users = instance_players

            subnet.add instance
          end
        end
      end
      # Recursively create EC2 Objects
      cloud.startup
    end
  end
end
