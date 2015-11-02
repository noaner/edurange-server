class ScenarioManagement

	def obliterate_custom(name, user)
    path = "#{Settings.app_path}/scenarios/custom/#{user.id}/#{name.downcase}"
    if not File.exists? path
      return false
    end
    path_graveyard = "#{Settings.app_path}/scenarios/custom/graveyard"
    FileUtils.mkdir path_graveyard if not File.exists? path_graveyard
    path_graveyard_user = "#{path_graveyard}/#{user.id}"
    FileUtils.mkdir path_graveyard_user if not File.exists? path_graveyard_user

    path_graveyard_scenario = "#{path_graveyard_user}/#{name.downcase}"

    if File.exists? path_graveyard_scenario
      cnt = 1
      until not File.exists? path_graveyard_scenario
        path_graveyard_scenario = path_graveyard_scenario + cnt.to_s
        cnt += 1
      end
    end
    
    FileUtils.mv path, path_graveyard_scenario
    return name, path_graveyard_scenario
	end

	def clone_from_name(name, location, newname, user)
    location = location.to_sym
		clone = Scenario.new(name: newname.strip, location: :custom, user_id: user.id)

		# validate user
		if not user
			clone.errors.add(:user, 'not a valid user')
			return clone
		elsif not (user.is_instructor? or user.is_admin?)
			clone.errors.add(:user, 'user must be instructor or admin')
			return clone
		end

    # validate name
    if clone.name == ""
      clone.errors.add(:name, "Can not be blank")
      return clone
    elsif /\W/.match(clone.name)
      clone.errors.add(:name, "Name can only contain alphanumeric and underscore")
      return clone
    elsif /^_*_$/.match(clone.name)
      clone.errors.add(:name, "Name not allowed")
      return clone
    elsif (clone.name.downcase == name.downcase)
    	clone.errors.add(:name, "name and name of clone must not be the same")
      return clone
    end

    Scenario::locations.each do |location,v|
      if location == 'custom'
        path = "#{Settings.app_path}/scenarios/custom/#{user.id}/#{clone.name.downcase}"
      else
        path = "#{Settings.app_path}/scenarios/#{location}/#{clone.name.downcase}"
      end
      if File.exists? path
        clone.errors.add(:name, "Name taken")
        return clone
      end
    end

    # check that scenario exists for name
    if location == :custom
      scenario_path = "#{Settings.app_path}/scenarios/custom/#{user.id}/#{name.downcase}"
    else
     	scenario_path = "#{Settings.app_path}/scenarios/#{location}/#{name.downcase}"
    end
    scenario_path_yml = "#{scenario_path}/#{name.downcase}.yml"
    scenario_path_recipes = "#{scenario_path}/recipes"

   	if (File.exists? scenario_path or File.exists? scenario_path)
	   	if not (File.exists? scenario_path and File.exists? scenario_path)
	   		clone.errors.add(:name, "scenario to be cloned files are corrupt")
	   		return clone
	   	end
   	else
   		clone.errors.add(:name, "could not find scenario to clone")
   		return clone
   	end

    # make user directory if it doesn't already exist
    userdir = "#{Settings.app_path}/scenarios/custom/#{user.id}"
    Dir.mkdir userdir unless File.exists? userdir

    # make clone directory
    clone_path = "#{Settings.app_path}/scenarios/custom/#{user.id}/#{clone.name.downcase}"
    if File.exists? clone_path
    	clone.errors.add(:file, 'path already exists.')
    else
    	Dir.mkdir clone_path
    end

    # make recipe directory and copy every recipe
    Dir.mkdir "#{Settings.app_path}/scenarios/custom/#{user.id}/#{clone.name.downcase}/recipes"
    Dir.foreach(scenario_path_recipes) do |recipe|
      next if recipe == '.' or recipe == '..'
      FileUtils.cp "#{scenario_path_recipes}/#{recipe}", "#{clone.path_recipes}"
    end

    # Copy yml file and replace Name:
    newyml = File.open("#{Settings.app_path}/scenarios/custom/#{user.id}/#{clone.name.downcase}/#{clone.name.downcase}.yml", "w")
    File.open(scenario_path_yml).each do |line|
      if /\s*Name:\s*#{name}/.match(line)
        line = line.gsub("#{name}", clone.name)
      end
      newyml.write line
    end
    newyml.close

    if clone.errors.any?
    	FileUtils.rm_r clone.path
    end

    clone.save
    clone
	end

end