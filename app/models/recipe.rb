class Recipe < ActiveRecord::Base
  belongs_to :scenario
  has_many :role_recipes, dependent: :destroy
  has_one :user, through: :scenario

  validates :name, presence: true, uniqueness: { scope: :scenario, message: "Name taken" }
  after_validation :check_custom
  after_create :set_defaults

  after_save :update_scenario_modified
  after_destroy :update_scenario_modified

  def update_scenario_modified
    if self.scenario.custom?
      self.scenario.update(modified: true)
    end
  end

  def instances_stopped?
    self.scenario.instances.each do |instance|
      if not instance.stopped?
        instance.roles.each do |role|
          if role.recipes.select{ |recipe| recipe == self }.size > 0
            return false
          end
        end
      end
    end
    true
  end

  def filename
    if self.custom?
      if self.scenario.custom?
        return "#{Settings.app_path}/scenarios/user/#{self.scenario.user.id}/#{self.scenario.name.downcase}/recipes/#{self.name}.rb"
      else
        return "#{Settings.app_path}/scenarios/local/#{self.scenario.name.downcase}/recipes/#{self.name.downcase}.rb"
      end
    end
    "#{Settings.app_path}/scenarios/recipes/#{self.name.filename_safe}.rb.erb"
  end

  def check_custom
    if File.exists? "#{Settings.app_path}/scenarios/recipes/#{self.name.downcase}.rb.erb" and self.custom
      errors.add(:name, "A global recipe with that name already exists")
    end
  end

  def set_defaults
    if File.exists? "#{Settings.app_path}/scenarios/recipes/#{self.name.downcase}.rb.erb"
      self.custom = false
    else
      self.custom = true
      if not File.exists? self.filename
        FileUtils.touch self.filename
      end
    end
    self.save
  end

  def text
    File.read(self.filename)
  end

  def text_update(text)
    if self.custom
      f = File.open(self.filename, "w")
      f.write(text)
      f.close
    end
  end

end
