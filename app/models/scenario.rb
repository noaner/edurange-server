class Scenario < ActiveRecord::Base
  has_many :clouds, dependent: :delete_all
  validates_presence_of :name, :description
  attr_accessor :template # For picking a template when creating a new scenario
  enum status: [:stopped, :booting, :booted]
  # provides .stopped?, .booting?, .booted?, and .status (ret "stopped", "booting", or "booted")
  def boot
    if self.stopped?
      self.status = "booting"
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting scenario..."
      
      # "Boot"
      5.times do
        sleep 1
        # PrivatePub it, as well as append to @scenario's log & update.
        debug "Hello, world - scenario!"
      end
      
      # Boot Clouds
      self.clouds.each { |cloud| cloud.boot }
    end
  end
  def debug(message)
    log = self.log
    self.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
    end
    yield
  end
  handle_asynchronously :run_when_booted
end
