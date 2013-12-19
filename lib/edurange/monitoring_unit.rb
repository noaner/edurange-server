module Edurange
  class MonitoringUnit < ActiveRecord::Base
    belongs_to :scenario
    has_many :subnets
    validates_presence_of :cidr_block
  end
end
