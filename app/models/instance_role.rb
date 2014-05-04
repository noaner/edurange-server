class InstanceRole < ActiveRecord::Base
  belongs_to :instance
  belongs_to :role
end
