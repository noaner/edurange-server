module Edurange
  class Subnet < ActiveRecord::Base
    belongs_to :cloud
    has_many :instances
    validates_presence_of :cloud, :cidr_block

    def boot 
      info "In Subnet Boot"
      self.provider_boot
      execute_when_booted do
        info "Subnet booted."
        Edurange.add_progress
        self.instances.each do |instance|
          instance.boot
        end
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
