class Subnet < ActiveRecord::Base
  include Provider
  include Aws
  validates_presence_of :cidr_block, :cloud

  belongs_to :cloud

  has_many :instances, dependent: :destroy

  validate :cidr_block_must_be_within_cloud
  def cidr_block_must_be_within_cloud
    # TODO check cidr block within cloud
    true
  end

  def add_progress(val)
    # debug "Adding progress to subnet"
    # PrivatePub.publish_to "/scenarios/#{self.cloud.scenario.id}", subnet_progress: val
  end

  def owner?(id)
    return self.cloud.scenario.user_id == id
  end

  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
  end

  def instances_booting?
    return self.instances.select{ |i| i.booting? }.any?
  end

  def instances_boot_failed?
    return self.instances.select{ |i| i.boot_failed? }.any?
  end

  def instances_unbooting?
    return self.instances.select{ |i| i.unbooting? }.any?
  end

  def instances_unboot_failed?
    return self.instances.select{ |i| i.unboot_failed? }.any?
  end

  def instances_booted?
    return self.instances.select{ |i| i.booted? }.any?
  end

end
