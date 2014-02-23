module Edurange
  class Player < ActiveRecord::Base
    belongs_to :group
    
    validates_presence_of :group
    def password_hash
      # TODO Should read from a passwords.txt or something to avoid specifying anywhere. Or random generated.
      '$1$IX4FOOoL$Ui3SypXns9r1HuWAiWdsG.'
    end
  end
end
