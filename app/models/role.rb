class Role < ActiveRecord::Base
  has_many :instances, through: :instances_roles
  serialize :packages, Array
  serialize :recipes, Array
end
