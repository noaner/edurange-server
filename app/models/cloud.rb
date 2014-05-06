class Cloud < ActiveRecord::Base
  validates_presence_of :cidr_block, :scenario

  validates_associated :scenario

  belongs_to :scenario
  has_many :subnets, dependent: :delete_all
end
