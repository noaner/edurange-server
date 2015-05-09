class Scenario < ActiveRecord::Base
  include Aws
  include Provider
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :destroy
  has_many :questions, dependent: :destroy
  validates_presence_of :name, :description
  belongs_to :user
  before_destroy :purge, prepend: true

  def owner?(id)
    return self.user_id == id
  end

  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
  end

  def scenario
    return self
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
    some_booted = nil
    some_stopped = nil
    all_booted = true
    all_stopped = true
    failure = false

    self.reload

    if self.booting? or self.unbooting? or self.queued?
      return
    end

    self.clouds.each do |cloud|

      cloud.reload

      if cloud.booting?  or cloud.unbooting? or cloud.queued?
        return
      end

      # mark if stopped or booted
      if cloud.stopped?
        all_booted = false
        some_stopped = true
      elsif cloud.booted?
        some_booted = true
        all_stopped = false
      elsif cloud.boot_failed? or cloud.unboot_failed?
        failure = true
      end

      cloud.subnets.each do |subnet|

        subnet.reload

        if subnet.booting?  or subnet.unbooting? or subnet.queued?
          return
        end

        # mark if stopped or booted
        if subnet.stopped?
          all_booted = false
          some_stopped = true
        elsif subnet.booted?
          some_booted = true
          all_stopped = false
        elsif subnet.boot_failed? or subnet.unboot_failed?
          failure = true
        end

        subnet.instances.each do |instance|

          instance.reload

          if instance.booting?  or instance.unbooting? or instance.queued?
            return
          end

          # mark if stopped or booted
          if instance.stopped?
            all_booted = false
            some_stopped = true
          elsif instance.booted?
            some_booted = true
            all_stopped = false
          elsif instance.boot_failed? or instance.unboot_failed?
            failure = true
          end

        end

      end

    end

    if failure
      self.set_failure
    elsif all_stopped and some_stopped
      self.set_stopped
    elsif all_booted and some_booted
      self.set_booted
    elsif some_booted
      self.set_partially_booted
    end

  end

  private

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
      self.aws_scenario_scoring_purge
      return true
    end

end
