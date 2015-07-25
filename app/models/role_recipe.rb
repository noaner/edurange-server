class RoleRecipe < ActiveRecord::Base
  belongs_to :role 
  belongs_to :recipe
  has_one :user, through: :role
  has_one :scenario, through: :role

  validates :recipe_id, presence: true, uniqueness: { scope: :role, message: "Role already has recipe" }
  validate :instances_stopped

  after_save :update_scenario_modified
  after_destroy :update_scenario_modified

  def update_scenario_modified
    if self.recipe.scenario
      self.recipe.scenario.update(modified: true)
    end
  end

  def instances_stopped
    self.role.instance_roles.each do |instance_role|
      if not instance_role.instance.stopped?
        errors.add(:running, "instances using this role must be stopped before modification")
        return false
      end
    end
    true
  end

end
