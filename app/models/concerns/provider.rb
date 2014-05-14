module Provider
  extend ActiveSupport::Concern
  included do
    enum status: [:stopped, :booting, :booted]
  end
  def boot
    classname = self.class.to_s.downcase
    if self.stopped?
      debug "Booting #{classname}..."
      self.set_booting
      
      # Boot
      self.send("provider_#{classname}_boot")
      self.set_booted

      # Boot child objects
      if self.class == Scenario
        self.clouds.each { |cloud| cloud.boot }
        self.provider_scenario_final_setup
      elsif self.class == Cloud
        self.subnets.each { |subnet| subnet.boot }
      elsif self.class == Subnet
        self.instances.each { |instance| instance.boot }
      end

    end
  end
  def set_stopped
    self.status = "stopped"
    self.save!
  end
  def set_booting
    self.status = "booting"
    self.save!
  end
  def set_booted
    self.status = "booted"
    self.save!
  end
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
      classname = self.class.to_s.downcase
      self.run_provider_method("#{classname}_check_status")
    end
    yield
  end
  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^provider_(.+)$/
      run_provider_method($1, *args, &block)
    else
      super
    end
  end
  def run_provider_method(provider_method, *args, &block)
    self.send("#{Settings.driver}_#{provider_method}".to_sym)
  end

  def upload_scoring_url
    return self.send("#{Settings.driver}_upload_scoring_url".to_sym)
  end
end
