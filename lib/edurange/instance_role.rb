module Edurange
  class InstanceRole < ActiveRecord::Base
    belongs_to :role
    belongs_to :instance
  end
end
