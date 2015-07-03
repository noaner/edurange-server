MAX_CLOUD_CIDR_BLOCK = 16 # AWS Max. 16 == a /16 subnet. See CIDR notation
MIN_CLOUD_CIDR_BLOCK = 28 # AWS Min

module Cidr

  # Validation function that ensures the CIDR block provided is IPV4 and a network.
  # @return [nil]
  def cidr_block_valid?
    return unless self.cidr_block

    if IPAddress.valid_ipv4?(self.cidr_block.split('/')[0])
      mask = self.cidr_block.split('/')[1]
      if not mask
        errors.add(:cidr_block, "Need a subnet mask")
      elsif not /^\d*\d$/.match(mask)
        errors.add(:cidr_block, "Subnet mask is invalid!")
      elsif not (mask.to_i >= MAX_CLOUD_CIDR_BLOCK and mask.to_i <= MIN_CLOUD_CIDR_BLOCK)
        errors.add(:cidr_block, "Subnet mask must be between #{MAX_CLOUD_CIDR_BLOCK} - #{MIN_CLOUD_CIDR_BLOCK}")
      end
    else
      # Not an IP at all? Generic error! Whoo!
      errors.add(:cidr_block, "IP section is invalid!")
    end
  end

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

end