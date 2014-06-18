# This file is included in {Scenario}, {Cloud}, {Subnet} and {Instance}. Essentialy it has glue code for 
# both defining methods dynamically (within concerns such as Aws that handle provider specific API calls) as well as 
# routing those methods (within {#method_missing})    
# Apart from defining these methods, the only other role this file has is to declare the "status" column, an integer corresponding to
# three states stored in the local database. They can be :stopped, :booting, or :booted. All files which include {Provider} receive this,
# and helper methods to retrieve the database state. Check out enum in Rails.    
# When reading through this file (and other Concerns), think of the file including them as their "self". When a {Cloud} includes this file,
# any of these methods "self" will refer to that {Cloud cloud}.
module Provider
  extend ActiveSupport::Concern
  included do
    enum status: [:stopped, :booting, :booted]
  end
  # First it calls provider_boot on itself, then it calls "boot"
  # on all of its child objects, if it has any. Additionally maintains the state
  # property in the database.
  # @return [nil]
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
        Scoring.generate_scenario_urls(self)
        self.clouds.each { |cloud| cloud.boot }
        self.reload
        self.provider_scenario_final_setup
        Scoring.scenario_scoring(self)
      elsif self.class == Cloud
        self.subnets.each { |subnet| subnet.boot }
      elsif self.class == Subnet
        self.instances.each do |instance|
          if instance.roles[0]["recipes"].include?("scoring")
            Scoring.instance_scoring(instance)
          end
          instance.boot
        end
      end

    end
  end

  # Sets the database state property to "stopped"
  # @return [nil]
  def set_stopped
    self.status = "stopped"
    self.save!
  end

  # Sets the database state property to "booting"
  # @return [nil]
  def set_booting
    self.status = "booting"
    self.save!
  end

  # Sets the database state property to "booted"
  # @return [nil]
  def set_booted
    self.status = "booted"
    self.save!
  end
  
  # Polls the state in database, waiting to yield to given block until self is booted?
  # If self is not booted?, calls provider_check_status for self.
  # @param block The block to execute when self.booted?
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
      classname = self.class.to_s.downcase
      self.run_provider_method("#{classname}_check_status")
    end
    yield
  end
  # Dynamically calls the method provided, routing it through the provider concern specified at runtime by
  # Settings.driver.
  # @param meth The method to call
  # @param args The arguments to pass
  # @param block Any block arguments to pass
  # @see #run_provider_method
  # @return [nil]
  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^provider_(.+)$/
      run_provider_method($1, *args, &block)
    else
      super
    end
  end
  
  # Calls the method provided in the EDURange config, defined in the concerns for each Driver at runtime.
  # Currently does not pass arguments.
  # @return [nil]
  def run_provider_method(provider_method, *args, &block)
    self.send("#{Settings.driver}_#{provider_method}".to_sym)
  end
end
