class Subnet < ActiveRecord::Base
  include Provider
  include Aws
  validates_presence_of :cidr_block, :cloud

  belongs_to :cloud
  
  has_many :instances, dependent: :delete_all

  validate :cidr_block_must_be_within_cloud
  def cidr_block_must_be_within_cloud
    # TODO check cidr block within cloud
    true
  end

  def add_progress(val)
    # debug "Adding progress to subnet"
    PrivatePub.publish_to "/scenarios/#{self.cloud.scenario.id}", subnet_progress: val
  end
  def debug(message)
    log = self.cloud.scenario.log
    self.cloud.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.cloud.scenario.id}", log_message: message
  end
end
