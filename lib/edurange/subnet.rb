module Edurange
  class Subnet < ActiveRecord::Base
    belongs_to :cloud
    has_many :instances
    binding.pry
    validates_presence_of :cloud, :cidr_block

    def boot 
      self.provider_boot
      self.instances.each do |instance|
        instance.boot
      end
    end
    def execute_when_booted
      # Fork
      # Poll self.booted?
      # if true: yield
      dispatch do
        until self.booted?
          sleep 2
        end
        yield
      end
    end
  end
end
