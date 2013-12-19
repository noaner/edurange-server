class Role < ActiveRecord::Base
  has_many :instances
  serialize :packages, Array
  serialize :recipes, Array
end
