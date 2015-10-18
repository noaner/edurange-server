class Recipe < ActiveRecord::Base
  belongs_to :scenario
  has_many :role_recipes, dependent: :destroy
  has_one :user, through: :scenario

  validates :name, presence: true, uniqueness: { scope: :scenario, message: "Name taken" }

  after_create :set_custom

  after_save :update_scenario_modified
  after_destroy :update_scenario_modified

  def update_scenario_modified
    if self.scenario.modifiable?
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

  def path
    if self.custom?
      return "#{self.scenario.path_recipes}/#{self.name.filename_safe}.rb"
    end
    "#{Settings.app_path}/scenarios/recipes/#{self.name.downcase}.rb.erb"
  end

  def set_custom
    if File.exists? "#{Settings.app_path}/scenarios/recipes/#{self.name.downcase}.rb.erb"
      self.custom = false
    else
      self.custom = true
      if not File.exists? self.path
        FileUtils.touch self.path
      end
    end
    self.save
  end

  def text
    File.read(self.path)
  end

  def text_update(text)
    if self.custom
      f = File.open(self.path, "w")
      f.write(text)
      f.close
    end
  end

end
