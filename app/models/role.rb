class Role < ActiveRecord::Base
  has_many :instances, through: :instances_roles
  serialize :packages, Array
  serialize :recipes, Array

  def scenario
  	ir = InstanceRole.find_by_role_id(self.id)
  	return ir.instance.scenario if ir
  	nil
  end

  def add_global_recipe(recipe)
    recipe = recipe.filename_safe

  	if not self.scenario.custom?
  		self.errors.add(:custom, "Scenario is not customizable")
  		puts self.errors.any?
  		return
  	end

    if self.recipes.include? recipe
      self.errors.add(:included, "Recipe '#{recipe}' is already included in role")
      return
    end

    if File.exists? "#{Settings.app_path}scenarios/user/#{self.scenario.user.name.filename_safe}/#{self.scenario.name.filename_safe}/recipes/#{recipe}.rb"
      self.errors.add(:recipe, "A custom recipe with that name already exists.")
      return
    end

  	if not File.exists? "#{Settings.app_path}/scenarios/recipes/#{recipe}.rb.erb"
  		self.errors.add(:recipe, "Recipe does not exist")
  		return
  	end

  	self.update_attribute(:recipes, self.recipes << recipe)
  end

  def add_custom_recipe(recipe, text)
    recipe = recipe.filename_safe

    if not self.scenario.custom?
      self.errors.add(:custom, "Scenario is not customizable")
      return
    end

    if File.exists? "#{Settings.app_path}scenarios/recipes/#{recipe}.rb.erb"
      self.errors.add(:recipe_name, "A global recipe with this name already exists.")
      return
    end

    file = "#{self.scenario.path}/recipes/#{recipe}.rb"
    if File.exists? file
      self.errors.add(:recipe_name, "A custom recipe with that name already exists")
      return
    end

    f = File.open(file, "w")
    f.write(text)
    f.close
    self.update_attribute(:recipes, self.recipes << recipe)
  end

  def remove_recipe(recipe)
    recipe = recipe.filename_safe

    if not self.recipes.include? recipe
      self.errors.add(:include, "Recipe is not included in role")
      return
    end

    if not File.exists? "#{Settings.app_path}/scenarios/recipes/#{recipe}.rb.erb"
    	file = self.scenario.recipe_file_path(recipe)
    	if file
    		FileUtils.rm(file)
    	else
        self.errors.add(:exist, "Recipe does not exist")
        return
      end
    end

    self.update_attribute(:recipes, self.recipes -= [recipe])
  end

end
