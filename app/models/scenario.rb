class Scenario < ActiveRecord::Base
  enum status: [:booted, :booting, :running]
  # provides .booted?, .booting?, .stopped?, and .status (ret "booted", "booting", or "stopped")
  def boot
    # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
  end
end
