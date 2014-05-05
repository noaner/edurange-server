class Scenario < ActiveRecord::Base
  has_many :clouds
  validates_presence_of :name, :description
  attr_accessor :template # For picking a template when creating a new scenario
  enum status: [:stopped, :booting, :booted]
  # provides .stopped?, .booting?, .booted?, and .status (ret "stopped", "booting", or "booted")
  def boot
    self.status = "booting"
    # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
    5.times do
      sleep 1
      # PrivatePub it, as well as append to @scenario's log & update.
      PrivatePub.publish_to "/scenarios/#{self.id}", :log_message => "Hello, world!"
    end
  end
  def run_when_booted
    until self.booted?
      self.reload
    end
    yield
  end
  handle_asynchronously :run_when_booted
end
