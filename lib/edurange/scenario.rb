module Edurange
  class Scenario < ActiveRecord::Base
    has_many :monitoring_units
  end
end
