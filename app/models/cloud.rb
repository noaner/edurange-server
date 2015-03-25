MAX_CLOUD_CIDR_BLOCK = 16 # AWS Max. 16 == a /16 subnet. See CIDR notation
MIN_CLOUD_CIDR_BLOCK = 28 # AWS Min

# This file has a few validations, described below. It maintains state and
# attributes corresponding to an AWS Virtual Private Cloud object.

class Cloud < ActiveRecord::Base
  include Provider
  include Aws

  belongs_to :scenario
  has_many :subnets, dependent: :destroy
  has_one :user, through: :scenario

  # validations

  validates_presence_of :name, :cidr_block, :scenario
  validate :cidr_block_is_valid
  # Validation function that ensures CIDR block provided is within min and max constants defined globally in this file.
  # @return [nil]
  def cidr_block_is_within_limits
    our_cidr_block_nw = IPAddress(self.cidr_block).network

    max_cloud_size_nw = our_cidr_block_nw.clone
    max_cloud_size_nw.prefix = MAX_CLOUD_CIDR_BLOCK

    min_cloud_size_nw = our_cidr_block_nw.clone
    min_cloud_size_nw.prefix = MIN_CLOUD_CIDR_BLOCK

    unless max_cloud_size_nw.include? our_cidr_block_nw # Unless we're within max nw size
      errors.add(:cidr_block, "must be smaller than #{max_cloud_size_nw}!")
    end
    unless our_cidr_block_nw.include? min_cloud_size_nw # Unless we're larger than the min nw size
      errors.add(:cidr_block, "must be larger than #{min_cloud_size_nw}!")
    end
  end
  # Validation function that ensures the CIDR block provided is IPV4 and a network.
  # @return [nil]
  def cidr_block_is_valid
    return unless self.cidr_block
    if IPAddress.valid_ipv4?(self.cidr_block.split('/')[0])
      # Valid network bits
      if IPAddress::IPv4.new(self.cidr_block)
        # Valid cidr block
        # If it's valid, make sure within provider limits
        self.cidr_block_is_within_limits
      end
    else
      # Not an IP at all? Generic error! Whoo!
      errors.add(:cidr_block, "is invalid!")
    end
  end
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

end
