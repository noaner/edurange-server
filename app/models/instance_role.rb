class InstanceRole < ActiveRecord::Base
  belongs_to :instance
  belongs_to :role
  has_one :user, through: :instance
  has_one :scenario, through: :role

  validate :validate_instance_stopped
  before_destroy :validate_instance_stopped
  after_destroy :update_scenario_modified

  def validate_instance_stopped
    if not self.instance.stopped?
      errors.add(:running, "instance must be stopped")
      return false
    end
    if self.scenario.modifiable?
      self.scenario.update_attribute(:modified, true)
    end
    true
  end

  def update_scenario_modified
    if self.scenario.modifiable?
      self.scenario.update_attribute(:modified, true)
    end
    true
  end
  
end
