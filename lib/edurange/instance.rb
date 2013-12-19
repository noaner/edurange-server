module Edurange
  class Instance < ActiveRecord::Base
    validates_presence_of :os
    belongs_to :subnet

    has_and_belongs_to_many :roles
    has_and_belongs_to_many :groups

    # Hooks
    before_validation :generate_valid_ip
    def generate_valid_ip
      if self.ip.nil?
        # TODO Generate an ip from self.subnet.cidr_block.assign_address(:random) or something
        self.ip = '1.2.3.4'
      end
    end
    def add_administrator(group)

    end
    def add_user(group)

    end
  end
end
