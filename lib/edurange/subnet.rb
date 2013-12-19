module Edurange
  class Subnet < ActiveRecord::Base
    belongs_to :monitoring_unit
    has_many :instances
    def allow_traffic(cidr, options)
      # cidr = '10.0.0.0/24'
      # options = { all: :all, tcp: :ssh, ...}
    end
    def assign_ip(method = :random)
    end
  end
end
