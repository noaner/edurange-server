class Scenario < ActiveRecord::Base
  enum status: [:stopped, :booting, :booted]
  # provides .stopped?, .booting?, .booted?, and .status (ret "stopped", "booting", or "booted")
  def boot
    self.status = "booting"
    # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
    1.times do
      sleep 2 
      # PrivatePub it, as well as append to @scenario's log & update.
      PrivatePub.publish_to "/scenarios/#{self.id}", :log_message => "Hello, world!"
    end
  end
end
