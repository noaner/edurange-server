module Edurange
  class Group < ActiveRecord::Base
    has_and_belongs_to_many :players
  end
end
