class Scenario < ActiveRecord::Base
  include Aws
  include Provider
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :delete_all
  has_many :questions, dependent: :destroy
  validates_presence_of :name, :description

  def debug(message)
    log = self.log
    self.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
    puts "\nMESSAGE:#{self.id},#{message}\n"
  end

  def get_subnets
    subnets = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnets.push subnet
      end
    end
    return subnets
  end

  def get_instances
    instances = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          if !instances.include? instance
              instances.push instance
          end
        end
      end
    end
    return instances
  end

  def get_groups
    groups = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            found = false
            groups.each do |group|
              if group.name == instance_group.group.name
                found = true
              end
            end
            if !found
              groups.push(instance_group.group)
            end
          end
        end
      end
    end
    return groups
  end

  def get_players
    players = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            instance_group.group.players.each do |player|
              found = false
              players.each do |inplayer|
                if inplayer.login == player.login
                  found = true
                end
              end
              if !found
                players.push(player)
              end
            end
          end
        end
      end
    end
    return players
  end

  def get_roles
    roles = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.roles.each do |role|
            if !roles.include? role
              roles.push(role)
            end
          end
        end
      end
    end
    return roles
  end

end
