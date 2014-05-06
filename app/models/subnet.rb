class Subnet < ActiveRecord::Base
  validates_presence_of :cidr_block, :cloud

  belongs_to :cloud
  validates_associated :cloud
  
  has_many :instances, dependent: :delete_all

  validate :cidr_block_must_be_within_cloud
  enum status: [:stopped, :booting, :booted]
  def cidr_block_must_be_within_cloud
    # TODO check cidr block within cloud
    true
  end
  def boot
    if self.stopped?
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting subnet..."
      
      # "Boot"
      5.times do
        sleep 1
        # PrivatePub it, as well as append to @scenario's log & update.
        debug "Hello, world - subnet!"
      end
      
      # Boot Instances
      self.instances.each { |instance| instance.boot }
    end
  end
  def debug(message)
    log = self.cloud.scenario.log
    self.cloud.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
end
