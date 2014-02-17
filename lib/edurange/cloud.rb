module Edurange
  class Cloud < ActiveRecord::Base
    # Internal object representation of AWS VPCs
    # This is OK to do at the moment, as our YAML file contains a "VPC_Mask" declaration

    attr_accessor :driver_object, :igw, :nat_instance
    validates_presence_of :cidr_block, :scenario
    belongs_to :scenario
    has_many :subnets

    def boot
      self.provider_boot
      execute_when_booted do
        self.subnets.each do |subnet|
          subnet.boot
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
