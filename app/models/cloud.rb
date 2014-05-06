class Cloud < ActiveRecord::Base
  enum status: [:stopped, :booting, :booted]
  validates_presence_of :cidr_block, :scenario

  validates_associated :scenario

  belongs_to :scenario
  has_many :subnets, dependent: :delete_all
  def boot
    if self.stopped?
      self.status = "booting"
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting cloud..."
      
      # "Boot"
      5.times do
        sleep 1
        # PrivatePub it, as well as append to @scenario's log & update.
        debug "Hello, world - cloud!"
      end
      
      # Boot Subnets
      self.subnets.each { |subnet| subnet.boot }
    end
  end
  def debug(message)
    log = self.scenario.log
    self.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
end
