module Edurange
  class Instance < ActiveRecord::Base
    attr_accessor :ip, :os, :internet_accessible
    belongs_to :subnet
    has_many :groups
    has_many :roles
  end
end
