class Scenario < ActiveRecord::Base
  include Aws
  include Provider
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :destroy
  has_many :questions, dependent: :destroy
  validates_presence_of :name, :description
  belongs_to :user
  before_destroy :purge, prepend: true

  def owner?(id)
    return self.user_id == id
  end

  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
  end

  def scenario
    return self
  end

  def subnets
    subnets = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnets.push subnet
      end
    end
    return subnets
  end

  def instances
    instances = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          if !instances.include? instance
              instances.push instance
          end
        end
      end
    end
    return instances
  end

  def groups
    groups = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            found = false
            groups.each do |group|
              if group.name == instance_group.group.name
                found = true
              end
            end
            if !found
              groups.push(instance_group.group)
            end
          end
        end
      end
    end
    return groups
  end

  def players
    players = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            instance_group.group.players.each do |player|
              found = false
              players.each do |inplayer|
                if inplayer.login == player.login
                  found = true
                end
              end
              if !found
                players.push(player)
              end
            end
          end
        end
      end
    end
    return players
  end

  def roles
    roles = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.roles.each do |role|
            if !roles.include? role
              roles.push(role)
            end
          end
        end
      end
    end
    return roles
  end

  def public_instances_reachable?
    reachable
    return self.instances.select{ |i| not i.port_open?(22) }.any?
  end

  def instances_initialized?
    return self.instances.select{ |i| not i.initialized? }.any?
  end

  def clouds_booting?
    return self.clouds.select{ |c| c.booting? }.any?
  end

  def clouds_boot_failed?
    return self.clouds.select{ |c| c.boot_failed? }.any?
  end

  def clouds_unbooting?
    return self.clouds.select{ |c| c.unbooting? }.any?
  end

  def clouds_unboot_failed?
    return self.clouds.select{ |c| c.unboot_failed? }.any?
  end

  def clouds_booted?
    return self.clouds.select{ |c| c.booted? }.any?
  end

  def get_status
    return
    some_booted = nil
    some_stopped = nil
    all_booted = true
    all_stopped = true
    failure = false

    self.reload

    if self.booting? or self.unbooting? or self.queued?
      return
    end

    self.clouds.each do |cloud|

      cloud.reload

      if cloud.booting?  or cloud.unbooting? or cloud.queued?
        return
      end

      # mark if stopped or booted
      if cloud.stopped?
        all_booted = false
        some_stopped = true
      elsif cloud.booted?
        some_booted = true
        all_stopped = false
      elsif cloud.boot_failed? or cloud.unboot_failed?
        failure = true
      end

      cloud.subnets.each do |subnet|

        subnet.reload

        if subnet.booting?  or subnet.unbooting? or subnet.queued?
          return
        end

        # mark if stopped or booted
        if subnet.stopped?
          all_booted = false
          some_stopped = true
        elsif subnet.booted?
          some_booted = true
          all_stopped = false
        elsif subnet.boot_failed? or subnet.unboot_failed?
          failure = true
        end

        subnet.instances.each do |instance|

          instance.reload

          if instance.booting?  or instance.unbooting? or instance.queued?
            return
          end

          # mark if stopped or booted
          if instance.stopped?
            all_booted = false
            some_stopped = true
          elsif instance.booted?
            some_booted = true
            all_stopped = false
          elsif instance.boot_failed? or instance.unboot_failed?
            failure = true
          end

        end

      end

    end

    if failure
      self.set_failure
    elsif all_stopped and some_stopped
      self.set_stopped
    elsif all_booted and some_booted
      self.set_booted
    elsif some_booted
      self.set_partially_booted
    end

  end

  def clone(name)
    clone = Scenario.new

    userdir = "#{Settings.app_path}/scenarios/user/#{self.user.name.filename_safe}"
    Dir.mkdir userdir unless File.exists? userdir

    srcdir = "#{Settings.app_path}/scenarios/local/#{self.name.filename_safe}"
    destdir = "#{Settings.app_path}/scenarios/user/#{self.user.name.filename_safe}/#{name.filename_safe}"

    if File.exists?(destdir) or name.filename_safe == self.name.filename_safe
      clone.errors.add(:name, "This name is taken. Try another name")
      return clone
    end

    Dir.mkdir destdir
    Dir.mkdir "#{destdir}/recipes"
    ymlname = YAML.load_file("#{srcdir}/#{self.name.filename_safe}.yml")["Name"]

    # Copy yml file and replace Name:
    newyml = File.open("#{destdir}/#{name.filename_safe}.yml", "w")
    lines = File.open("#{srcdir}/#{self.name.filename_safe}.yml").each do |line|
      if /\s*Name:\s*#{self.name}/.match(line)
        line = line.gsub("#{self.name}", name)
      end
      puts line
      newyml.write line
    end
    newyml.close

    # copy cookbook and every recipe
    Dir.foreach("#{srcdir}/recipes") do |recipe|
      next if recipe == '.' or recipe == '..'
      FileUtils.cp "#{srcdir}/recipes/#{recipe}", "#{destdir}/recipes"
    end

    clone = YmlRecord.load_yml(name, self.user, false)
  end

  def path
    local = "#{Settings.app_path}scenarios/local/#{self.name.filename_safe}"
    return local if File.exists? local
    return "#{Settings.app_path}scenarios/user/#{self.user.name.filename_safe}/#{self.name.filename_safe}"
  end

  def recipe_global?(recipe)
    recipe = recipe.filename_safe
    return File.exists? "#{Settings.app_path}/recipes/#{recipe}.rb.erb"
  end

  def recipe_file_path(recipe)
    recipe = recipe.filename_safe
    local = "#{self.path}/recipes/#{recipe}.rb"
    shared = "#{Settings.app_path}scenarios/recipes/#{recipe}.rb.erb"
    if File.exists? local
      return local
    elsif File.exists? shared
      return shared
    end
    nil
  end

  def recipe_text(recipe)
    recipe = recipe.filename_safe
    local = "#{self.path}/recipes/#{recipe}.rb"
    shared = "#{Settings.app_path}scenarios/recipes/#{recipe}.rb.erb"
    if File.exists? local
      text = File.read(local)
    elsif File.exists? shared
      text = File.read(shared)
    end
    text
  end

  def recipe_update(recipe, text)
    recipe = recipe.filename_safe
    local = "#{self.path}/recipes/#{recipe}.rb"
    shared = "#{Settings.app_path}scenarios/recipes/#{recipe}.rb.erb"

    if File.exists? local
      file = local
    elsif File.exists? shared
      file = shared
    end

    f = File.open(file, "w")
    f.write(text)
    f.close
  end

  def get_global_recipes_and_descriptions
    recipes = { }
    Dir.foreach("#{Settings.app_path}/scenarios/recipes") do |file|
      next if file == '.' or file == '..'

      recipe = file.gsub(".rb.erb", "")
      description = ''
      description_file = "#{Settings.app_path}/scenarios/recipes/descriptions/#{recipe}"
      if File.exists? description_file
        description += File.open(description_file).read
      end
      recipes[recipe] = description 
    end
    recipes
  end

  def update_yml
    if File.exists? "#{Settings.app_path}scenarios/local/#{self.name.filename_safe}"
      self.errors.add(:customizable, "Scenario is not customizable")
      return
    end

    yml = { 
      "Name" => self.name, 
      "Description" => self.description,
      "Groups" => nil,
      "Clouds" => nil,
      "Subnets" => nil,
      "Instances" => nil
    }

    yml["Roles"] = self.roles.empty? ? nil : self.roles.map { |r|
      { "Name"=>r.name, 
        "Packages" => r.packages.empty? ? nil : r.packages, 
        "Recipes"=>r.recipes.empty? ? nil : r.recipes 
      }
    }

    yml["Groups"] = self.groups.empty? ? nil : self.groups.map { |group| 
      { "Name" => group.name, 
        "Access" => { 
          "Administrator" => group.instance_groups.select{ |ig| ig.administrator  }.map{ |ig| ig.instance.name },
          "User" => group.instance_groups.select{ |ig| not ig.administrator  }.map{ |ig| ig.instance.name }
        },
        "Users" => group.players.empty? ? nil : group.players.map { |p| { "Login" => p.login, "Password" => p.password} }
      }
    }

    yml["Clouds"] = self.clouds.empty? ? nil : self.clouds.map { |cloud|
      { "Name" => cloud.name, "CIDR_Block" => cloud.cidr_block}
    }

    yml["Subnets"] = self.subnets.empty? ? nil : self.subnets.map { |subnet| {
        "Name" => subnet.name, 
        "Cloud" => subnet.cloud.name, 
        "CIDR_Block" => subnet.cidr_block, 
        "Internet_Accessible" => subnet.internet_accessible
      }
    }

    yml["Instances"] = self.instances.empty? ? nil : self.instances.map { |instance| {
        "Name" => instance.name, 
        "Subnet" => instance.subnet.name,
        "OS" => instance.os,
        "IP_Address" => instance.ip_address, 
        "Internet_Accessible" => instance.internet_accessible,
        "Roles" => instance.roles.map { |r| r.name }
      }
    }

    f = File.open("#{self.path}/#{self.name.filename_safe}.yml", "w")
    f.write(yml.to_yaml)
    f.close()
  end

  def change_name(name)
    if not self.custom?
      self.errors.add(:custom, "Scenario must be custom to change name")
      return
    end

    local_path = "#{Settings.app_path}scenarios/local/#{name.filename_safe}"
    custom_path = "#{Settings.app_path}scenarios/user/#{self.user.name.filename_safe}/#{name.filename_safe}"

    if not self.stopped?
      self.errors.add(:running, "Scenario must be stopped before name can be changed")
    elsif File.exists? local_path or File.exists? custom_path
      self.errors.add(:name, "Name taken")
    else
      oldpath = self.path
      oldname = self.name
      self.name = name

      FileUtils.cp_r oldpath, self.path
      FileUtils.mv "#{self.path}/#{oldname.filename_safe}.yml", "#{self.path}/#{self.name.filename_safe}.yml"
      FileUtils.rm_r "#{oldpath}"
      self.update_yml
      self.save
    end
  end

  private

    def purge
      self.clouds.each do |cloud|
        cloud.subnets.each do |subnet|
          subnet.instances.each do |instance|
            instance.instance_groups.each do |instance_group|
              Group.where(:id => instance_group.group_id).destroy_all
              Player.where(:group_id => instance_group.group_id).destroy_all
              InstanceGroup.where(:id => instance_group.id).destroy_all
            end
            role_id = InstanceRole.where(:instance_id => instance.id).pluck(:role_id).first
            Role.where(:id => role_id).destroy_all
          end
        end
      end
      self.aws_scenario_scoring_purge
      return true
    end

end
