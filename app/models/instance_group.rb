class InstanceGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :instance
  has_one :user, through: :instance
  has_one :scenario, through: :group

  after_save :update_scenario_modified
  after_destroy :update_scenario_modified

  def update_scenario_modified
    if self.scenario.modifiable?
      return self.instance.scenario.update_attribute(:modified, true)
    end
    false
  end

  def validate
    if not self.instance.stopped?
      errors.add(:name, "instance must be stopped first")
      return false
    end
    if InstanceGroup.where("group_id = ? AND instance_id = ? AND administrator = ?", self.group_id, self.instance_id, self.administrator).size > 0
      errors.add(:name, "Already exists")
      return false
    end
    true
  end

end
