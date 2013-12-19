module Edurange
  class InstanceRoles < ActiveRecord::Base
    belongs_to :role
    belongs_to :instance
  end
end
