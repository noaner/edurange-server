class InstanceGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :instance
  has_one :user, through: :instance
end
