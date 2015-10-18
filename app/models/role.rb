class Role < ActiveRecord::Base
  belongs_to :scenario
  has_many :role_recipes, dependent: :destroy
  has_many :recipes, through: :role_recipes
  has_many :instance_roles, dependent: :destroy
  has_one :user, through: :scenario

  serialize :packages, Array

  validates :name, presence: true, uniqueness: { scope: :scenario, message: "Name taken" }
  validate :instances_stopped

  before_destroy :instances_stopped, prepend: :true
  after_destroy :update_scenario_modified

  def instances_stopped
    self.instance_roles.each do |instance_role|
      if not instance_role.instance.stopped?
        errors.add(:running, "instances using this role must be stopped before deletion")
        return false
      end
    end
    if self.scenario.modifiable?
      self.scenario.update(modified: true)
    end
    true
  end

  def update_scenario_modified
    if self.scenario.modifiable?
      self.scenario.update_attribute(:modified, true)
    end
    true
  end

  def instances_stopped?
    self.instance_roles.each do |instance_role|
      return false if not instance_role.instance.stopped? 
    end
    true
  end

end
