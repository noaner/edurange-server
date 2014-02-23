module Edurange
  class Scenario < ActiveRecord::Base
    has_many :clouds
    def boot
      self.clouds.each do |cloud|
        cloud.boot
      end
      self.final_setup
    end
  end
end
