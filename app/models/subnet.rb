class Subnet < ActiveRecord::Base
  validates_presence_of :cidr_block, :cloud

  belongs_to :cloud
  validates_associated :cloud
  
  has_many :instances

  validate :cidr_block_must_be_within_cloud
  def cidr_block_must_be_within_cloud
    # TODO check cidr block within cloud
    true
  end
end
