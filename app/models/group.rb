class Group < ActiveRecord::Base
  has_many :instance_groups
  has_many :instances, through: :instance_groups
  has_many :players
end
