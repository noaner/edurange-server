class MonitoringUnit < ActiveRecord::Base
  validates_presence_of :cidr_block
end
