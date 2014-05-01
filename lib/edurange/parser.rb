module Edurange
  class Parser
    def self.load_from_yaml(path)
      file = YAML.load_file(path)

      scenarios = file["Scenarios"]
      clouds = file["Clouds"]
      subnets = file["Subnets"]
      instances = file["Instances"]
      roles = file["Roles"]
      groups = file["Groups"]

      roles.each do |yaml_role|
        role = Role.new
        role.name = yaml_role["Name"]
        if yaml_role["Recipes"]
          yaml_role["Recipes"].each { |recipe| role.recipes << recipe }
        end
        if yaml_role["Packages"]
          yaml_role["Packages"].each { |package| role.packages << package }
        end
        role.save!
      end
      
      

      scenarios.each do |yaml_scenario|
        scenario = Scenario.new
        scenario.name = yaml_scenario["Name"]
        scenario.game_type = yaml_scenario["Game_Type"]
        scenario.save!
      end
      
      clouds.each do |yaml_cloud|
        cloud = Cloud.new
        cloud.name = yaml_cloud["Name"]
        cloud.cidr_block = yaml_cloud["CIDR_Block"]
        cloud.scenario = Scenario.find_by_name yaml_cloud["Scenario"]
        cloud.save!
      end

      subnets.each do |yaml_subnet|
        subnet = Subnet.new
        subnet.cloud = Cloud.find_by_name yaml_subnet["Cloud"]
        subnet.name = yaml_subnet["Name"]
        subnet.cidr_block = yaml_subnet["CIDR_Block"]
        if yaml_subnet["Internet_Accessible"]
          subnet.internet_accessible = true
        end
        subnet.save!
      end

      instances.each do |yaml_instance|
        instance = Instance.new
        instance_roles = yaml_instance["Roles"]
        instance.subnet = Subnet.find_by_name yaml_instance["Subnet"]
        instance.name = yaml_instance["Name"]
        instance.ip_address = yaml_instance["IP_Address"]
        if yaml_instance["Internet_Accessible"]
          instance.internet_accessible = true
        end
        instance.os = yaml_instance["OS"]
        instance_roles.each do |instance_role|
          role = Role.find_by_name instance_role
          instance.roles << role
        end
        instance.save!
      end
      
      
      groups.each do |yaml_group|
        users = yaml_group["Users"]
        access = yaml_group["Access"]
        admin = access["Administrator"]
        user = access["User"]

        group = Group.new
        group.name = yaml_group["Name"]
        group.save!

        users.each do |user|
          login = user["Login"]
          password = user["Password"]

          player = group.players.new
          player.login = login
          player.password = password
          player.group = group
          player.save!
        end

        # Give group admin on machines they own
        if admin
          admin.each do |admin_instance|
            instance = Instance.find_by_name(admin_instance)
            instance.add_administrator(group)
            instance.save!
          end
        end
        
        if user
          user.each do |user_instance|
            instance = Instance.find_by_name(user_instance)
            instance.add_user(group)
            instance.save!
          end
        end
      end
      Scenario.all.each { |scenario| scenario.boot }

      users = []
      Group.all.each do |group|
        users << group.players
      end
      users.flatten!
      subnet = Subnet.find_by_name("Battlespace_Subnet")
      if subnet
        File.open(ENV['HOME'] + "/edurange_scoring/db/nodes.txt", "w") do |file|
          subnet.instances.each do |instance|
            file.puts instance.ip_address
          end
        end
        File.open(ENV['HOME'] + "/edurange_scoring/db/users.txt", "w") do |file|
          users.each do |user|
            file.puts "#{user.login},#{user.password}"
          end
        end
      end
      puts "======================================"
      puts "==== EDURange has booted. Please  ===="
      puts "==== cd into ~/edurange_scoring   ===="
      puts "==== and run ./scoring_server.sh  ===="
      puts "======================================"
    end
  end
end
