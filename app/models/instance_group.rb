class InstanceGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :instance
end
