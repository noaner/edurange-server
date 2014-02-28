module Edurange
  class Player < ActiveRecord::Base
    belongs_to :group
    
    validates_presence_of :group
    def password_hash
      UnixCrypt::SHA512.build(self.password)
    end
  end
end
