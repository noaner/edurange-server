MAX_CLOUD_CIDR_BLOCK = 16 # AWS Max. 16 == a /16 subnet. See CIDR notation
MIN_CLOUD_CIDR_BLOCK = 28 # AWS Min

class Cloud < ActiveRecord::Base
  include Provider
  include Aws

  belongs_to :scenario
  has_many :subnets, dependent: :delete_all

  # validations

  validates_presence_of :name, :cidr_block, :scenario
  validate :cidr_block_is_valid

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
  # logging functions
  def add_progress
    PrivatePub.publish_to "/scenarios/#{self.scenario.id}", cloud_progress: 1
  end
  def debug(message)
    log = self.scenario.log
    self.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
end
