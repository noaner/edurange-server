module Edurange
  class Player < ActiveRecord::Base
    belongs_to :group
    
    validates_presence_of :group
    # Hooks
    before_validation :generate_valid_ssh_key
    def generate_valid_ssh_key
      if self.ssh_key.nil?
        # TODO Generate an ip from self.subnet.cidr_block.assign_address(:random) or something
        self.ssh_key = 'ssh-rsa...'
      end
    end
  end
end
