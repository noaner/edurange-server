module YmlRecord
  # Returns an array of [filename, scenario name, description]
  def self.yml_headers_old
    output = []
    Dir.foreach(Settings.app_path + "scenarios-yml/") do |filename|
      next if filename == '.' or filename == '..' or filename == 'ddos.yml'
      scenario = YAML.load_file(Settings.app_path + "scenarios-yml/#{filename}")["Scenarios"][0]
      name = scenario["Name"]
      description = scenario["Description"]
      output.push [filename, name, description]
    end
    return output
  end

  def self.yml_headers
    output = []
    Dir.foreach(Settings.app_path + "scenarios/local") do |filename|
      next if filename == '.' or filename == '..' or filename == 'ddos.yml'
      scenario = YAML.load_file(Settings.app_path + "scenarios/local/#{filename}/#{filename}.yml")["Scenarios"][0]
      name = scenario["Name"]
      description = scenario["Description"]
      output.push [filename, name, description]
    end
    return output
  end

  def self.get_scoring_info(yaml_file)
    file = YAML.load_file(yaml_file)
    return [file["Scenarios"][0]["Name"], file["Answers"]]
  end

  # Returns a new Scenario with subobjects
  def self.load_yml(yaml_file)
    name_lookup_hash = Hash.new
    # Because in the YML we establish relationships by name we need to keep track of
    # what unique id corresponds to the current loading of the scenario. Whenever we
    # create an object, we store it within the above hash so that we can look it up
    # later in this function when we are creating objects referencing things in the database.
    puts yaml_file
    file = YAML.load_file(Settings.app_path + yaml_file)

    scenarios = file["Scenarios"]
    clouds = file["Clouds"]
    subnets = file["Subnets"]
    instances = file["Instances"]
    roles = file["Roles"]
    groups = file["Groups"]
    questions = file["Questions"]
    answers = file["Answers"]

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
      name_lookup_hash[role.name] = role.id
    end

    scenario = nil # Set scope for scenario
    scenarios.each do |yaml_scenario|
      scenario = Scenario.new
      scenario.name = yaml_scenario["Name"]
      scenario.description = yaml_scenario["Description"]
      scenario.instructions = yaml_scenario["Instructions"]
      answers ||= []
      scenario.answers = answers.join("\n")
      scenario.uuid = `uuidgen`.chomp
      scenario.save!
      name_lookup_hash[scenario.name] = scenario.id
    end

    cloud = nil
    clouds.each do |yaml_cloud|
      scenario = Scenario.find(name_lookup_hash[yaml_cloud["Scenario"]])
      cloud = scenario.clouds.new
      cloud.name = yaml_cloud["Name"]
      cloud.cidr_block = yaml_cloud["CIDR_Block"]
      cloud.save!
      name_lookup_hash[cloud.name] = cloud.id
    end

    subnets.each do |yaml_subnet|
      cloud = Cloud.find(name_lookup_hash[yaml_subnet["Cloud"]])
      subnet = cloud.subnets.new
      subnet.name = yaml_subnet["Name"]
      subnet.cidr_block = yaml_subnet["CIDR_Block"]
      if yaml_subnet["Internet_Accessible"]
        subnet.internet_accessible = true
      end
      subnet.save!
      name_lookup_hash[subnet.name] = subnet.id
    end


    instance = nil
    instance_ips = {}
    instances.each do |yaml_instance|
      instance = Instance.new
      instance_roles = yaml_instance["Roles"]
      instance.subnet = Subnet.find(name_lookup_hash[yaml_instance["Subnet"]])
      instance.name = yaml_instance["Name"]

      ipaddress, instance_ips = self.parse_ip(yaml_instance["IP_Address"], instance_ips)
      if ipaddress == nil
        scenario.destroy
        raise "ERROR - could not assign IP adress to Instance"
      end

      instance.ip_address = ipaddress

      if yaml_instance["Internet_Accessible"]
        instance.internet_accessible = true
      end
      instance.os = yaml_instance["OS"]
      instance_roles.each do |instance_role|
        role = Role.find(name_lookup_hash[instance_role])
        instance.roles << role
      end
      instance.uuid = `uuidgen`.chomp
      instance.save!
      name_lookup_hash[instance.name] = instance.id
    end


    groups.each do |yaml_group|
      users = yaml_group["Users"]
      access = yaml_group["Access"]
      admin = access["Administrator"]
      user = access["User"]

      group = Group.new
      group.name = yaml_group["Name"]
      group.scenario_id = scenario.id
      group.save!

      if users
        users.each do |user|
          login = user["Login"]
          password = user["Password"]

          player = group.players.new
          player.login = login
          player.password = password
          player.group = group
          player.save!
        end
      end

      # Do questions
      if questions
        questions.each do |yml_question|
          question = scenario.questions.new
          question.question_text = yml_question["Question"]
          question.kind = yml_question["Type"]
          if question.kind == "StringMatch"
            question.answer_text = yml_question["Answer"]
          end
          question.save!
        end
      end

      # Give group admin on machines they own
      if admin
        admin.each do |admin_instance|
          instance = Instance.find(name_lookup_hash[admin_instance])
          instance.add_administrator(group)
          instance.save!
        end
      end

      if user
        user.each do |user_instance|
          instance = Instance.find(name_lookup_hash[user_instance])
          instance.add_user(group)
          instance.save!
        end
      end
    end
    return scenario # Return the scenario we created
  end

  def self.write_yml(yaml_file, scenario)
    File.open(yaml_file, 'w') do |f|
      f.puts scenario.to_yaml
    end
  end

  def self.parse_ip(ip, ips)
    ipnew = ""
    block = ips
    ran = nil

    ip_split = ip.split(".")
    ip_split.each_with_index do |num, i|

      # get block or create new one
      if not i == ip_split.size - 1

        if block[num]
          block = block[num]
        else
          # insert hash unless last block then insert array
          if i== (ip_split.size - 2)
            block[num] = []
          else
            block[num] = {}
          end
          block = block[num]
        end

      end

      # If range
      num = num.split("-")
      if num.size > 1

          # get low and high ranges
          low = num[0].to_i
          high = num[1].to_i

          # if last block check for room, if no room return false
          if i == ip_split.size-1
            if high-low+1 <= block.size
              return nil, nil
            end
          end

          # get random number, reroll if already taken
          ran = Random.new.rand(num[0].to_i..num[1].to_i).to_s
          until not block.include?(ran)
            ran = Random.new.rand(num[0].to_i..num[1].to_i).to_s
          end
          ipnew += ran + "."
      else
        ipnew += num[0] + "."
      end

    end
    block.push(ran)

    return ipnew.chop, ips
  end

end
