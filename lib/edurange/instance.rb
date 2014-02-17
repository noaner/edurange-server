module Edurange
  class Instance < ActiveRecord::Base
    validates_presence_of :os, :subnet
    belongs_to :subnet

    has_many :instance_groups
    has_many :instance_roles
    has_many :groups, through: :instance_groups
    has_many :roles, through: :instance_roles

    # Handy user methods
    def administrators
      self.instance_groups.select {|instance_group| instance_group.administrator }.map {|instance_group| instance_group.group}
    end
    def users
      self.instance_groups.select {|instance_group| !instance_group.administrator }.map {|instance_group| instance_group.group}
    end

    def add_administrator(group)
      InstanceGroup.create(group: group, instance: self, administrator: true)
    end
    def add_user(group)
      InstanceGroup.create(group: group, instance: self, administrator: false)
    end

    def execute_when_booted
      # Fork
      # Poll self.booted?
      # if true: yield
      dispatch do
        until self.booted?
          sleep 2
        end
        yield
        
      end
    end

    def boot
      # Chef create users
      # Chef install required packages
      # Chef configure other stuff
      if self.nat?
        # Create chef cookbook for nat
      end
      self.provider_boot
    end
  end
end
