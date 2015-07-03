# This file has a few validations, described below. It maintains state and
# attributes corresponding to an AWS Virtual Private Cloud object.

class Cloud < ActiveRecord::Base
  include Provider
  include Aws
  include Cidr

  belongs_to :scenario
  has_many :subnets, dependent: :destroy
  has_one :user, through: :scenario

  # validations
  validates :name, presence: true, uniqueness: { scope: :scenario, message: "name already taken" } 

  validates_presence_of :cidr_block, :scenario
  # validate :cidr_block_valid?, :cidr_encompasses_subnets?
  validate :cidr_validate

  # Debug function that adds 1 to this scenario's "cloud_progress", increasing the progress bar on the boot view.
  # @return [nil]
  def add_progress(val)
    # PrivatePub.publish_to "/scenarios/#{self.scenario.id}", cloud_progress: val
  end
  # @param message The message to print to the {Scenario}'s boot view
  # @return [nil]
  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
  end

  def owner?(id)
    return self.scenario.user_id == id
  end

  def ip_taken?(ip)
    return self.subnets.select{ |subnet| subnet.instances.select{ |instance| instance.ip_address == ip }.size > 0 }.size > 0
  end

  def subnets_booting?
    return self.subnets.select{ |s| s.booting? }.any?
  end

  def subnets_boot_failed?
    return self.subnets.select{ |s| s.boot_failed? }.any?
  end

  def subnets_unbooting?
    return self.subnets.select{ |s| s.unbooting? }.any?
  end

  def subnets_unboot_failed?
    return self.subnets.select{ |s| s.unboot_failed? }.any?
  end

  def subnets_booted?
    return self.subnets.select{ |s| s.booted? }.any?
  end

  def cidr_validate

    # Check for valid CIDR
    if IPAddress.valid_ipv4?(self.cidr_block.split('/')[0])
      mask = self.cidr_block.split('/')[1]
      if not mask
        errors.add(:cidr_block, "Need a subnet mask")
        return
      elsif not /^\d*\d$/.match(mask)
        errors.add(:cidr_block, "Subnet mask is invalid!")
        return
      elsif not (mask.to_i >= MAX_CLOUD_CIDR_BLOCK and mask.to_i <= MIN_CLOUD_CIDR_BLOCK)
        errors.add(:cidr_block, "Subnet mask must be between #{MAX_CLOUD_CIDR_BLOCK} - #{MIN_CLOUD_CIDR_BLOCK}")
        return
      end
    else
      # Not an IP at all? Generic error! Whoo!
      errors.add(:cidr_block, "IP section is invalid!")
      return
    end

    # Check that each subnet of cloud is within cloud CIDR
    self.subnets.each do |subnet|
      ord = NetAddr::CIDR.create(self.cidr_block).cmp(subnet.cidr_block)
      puts subnet.cidr_block + " " + ord.to_s
      if ord != 1 and ord != 0
        self.errors.add(:cidr_block, "CIDR block does not encompass #{subnet.name}")
        return
      end
    end

  end

end
