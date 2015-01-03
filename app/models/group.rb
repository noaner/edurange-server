class Group < ActiveRecord::Base
  has_many :instance_groups
  has_many :instances, through: :instance_groups
  has_many :players, dependent: :destroy
  # Handy user methods
  def administrative_access_to
    instances = self.instance_groups.select {|instance_group| instance_group.administrator }.map {|instance_group| instance_group.instance}
  end

  def user_access_to
    instances = self.instance_groups.select {|instance_group| !instance_group.administrator }.map {|instance_group| instance_group.instance}
  end
end
