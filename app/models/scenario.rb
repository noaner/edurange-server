class Scenario < ActiveRecord::Base
  include Aws
  include Provider
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :destroy
  has_many :questions, dependent: :destroy
  validates_presence_of :name, :description
  belongs_to :user

  def owner?(id)
    return self.user_id == id
  end

  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
  end

  def purge
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            Group.where(:id => instance_group.group_id).destroy_all
            Player.where(:group_id => instance_group.group_id).destroy_all
            InstanceGroup.where(:id => instance_group.id).destroy_all
          end
          role_id = InstanceRole.where(:instance_id => instance.id).pluck(:role_id).first
          Role.where(:id => role_id).destroy_all
        end
      end
    end
  end

  def subnets
    subnets = []
    self.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnets.push subnet
      end
    end
    return subnets
  end

  def instances
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

  def groups
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

  def players
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

  def roles
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

  def public_instances_reachable?
    reachable
    return self.instances.select{ |i| not i.port_open?(22) }.any?
  end

  def instances_initialized?
    return self.instances.select{ |i| not i.initialized? }.any?
  end

  def clouds_booting?
    return self.clouds.select{ |c| c.booting? }.any?
  end

  def clouds_boot_failed?
    return self.clouds.select{ |c| c.boot_failed? }.any?
  end

  def clouds_unbooting?
    return self.clouds.select{ |c| c.unbooting? }.any?
  end

  def clouds_unboot_failed?
    return self.clouds.select{ |c| c.unboot_failed? }.any?
  end

  def clouds_booted?
    return self.clouds.select{ |c| c.booted? }.any?
  end

  def get_status

    all_stopped = true
    all_booted = true

    boot_failed = nil
    unboot_failed = nil

    booting = nil
    unbooting = nil

    self.clouds.each do |cloud|

      if cloud.boot_failed?
        self.set_boot_failed
        return
      elsif cloud.unboot_failed?
        self.set_unboot_failed
        return
      end
      
      if cloud.booted?
        all_stopped = false
      elsif cloud.stopped?
        all_booted = false
      elsif cloud.booting?
        booting = true
      elsif cloud.unbooting?
        unbooting = true
      end

      cloud.subnets.each do |subnet|

        if subnet.boot_failed?
          self.set_boot_failed
          return
        elsif subnet.unboot_failed?
          self.set_unboot_failed
          return
        end
        
        if subnet.booted?
          all_stopped = false
        elsif subnet.stopped?
          all_booted = false
        elsif subnet.booting?
          booting = true
        elsif subnet.unbooting?
          unbooting = true
        end

        subnet.instances.each do |instance|

          if instance.boot_failed?
            self.set_boot_failed
            return
          elsif instance.unboot_failed?
            self.set_unboot_failed
            return
          end
          
          if instance.booted?
            all_stopped = false
          elsif instance.stopped?
            all_booted = false
          elsif instance.booting?
            booting = true
          elsif instance.unbooting?
            unbooting = true
          end

        end
      end
    end

    if all_stopped and not self.booting?
      self.set_stopped
    elsif all_booted
      self.set_booted
    end

    if booting
      self.set_booting
    elsif unbooting
      self.set_unbooting
    end

  end

end
