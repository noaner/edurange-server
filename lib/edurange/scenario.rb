module Edurange
  class Scenario < ActiveRecord::Base
    has_many :clouds
    def boot
      self.clouds.each do |cloud|
        cloud.boot
      end
    end
  end
end
