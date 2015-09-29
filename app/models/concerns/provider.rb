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
    enum status: [:stopped, :paused, :pausing, :starting, :queued_boot, :queued_unboot, :booting, :booted, :failure, :boot_failed, :unboot_failed, :unbooting, :stopping, :partially_booted, :partially_booted_with_failure, :partially_unbooted, :partially_unbooted_with_failure]
  end

  def debug_booting
    debug "------------------ booting ------------------"
  end

  def debug_booting_finished
    debug "-------------- finished booting -------------"
  end

  def debug_unbooting
    debug "----------------- unbooting -----------------"
  end

  def debug_unbooting_finished
    debug "------------ finished unbooting ------------"
  end

  def clear_log
    self.update_attribute(:log, '')
  end

  #############################################################
  #  Booting

  def boot_error(error)

    self.set_boot_failed
    debug(error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n"));
    self.save
    self.reload

    self.scenario.set_boot_failed

    # time = Time.new
    # File.open("#{Rails.root}/log/boot.#{scenario.id}-#{scenario.name}.log", 'a') do |f|
      # f.puts "\n"
      # f.puts error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
      # f.puts "\n"
    # end
  end

  def boot(options = {})
    classname = self.class
    if classname == Scenario
      if not (self.stopped? or self.partially_booted?)
        errors.add(:boot, "#{self.class} must be stopped or partially booted to boot")
        return false
      end
    elsif not self.stopped?
      errors.add(:boot, "#{self.class} must be stopped to boot")
      return false
    end

    if classname == Subnet
      if not self.cloud.booted?
        errors.add(:boot, "Subnets cloud must be booted")
        return false
      end
    elsif classname == Instance
      if not self.subnet.booted?
        errors.add(:boot, "Instances subnet must be booted")
        return false
      end
    end 


    if classname == Scenario or classname = Cloud
      if AWS::EC2.new.vpcs.count >= Settings.vpc_limit
        errors.add(:boot, "VPC limit of #{Settings.vpc_limit} reached, find AWS edurange admin for help.")
        return false
      end
    end


    self.clear_log
    self.debug_booting
    
    if options[:debug]
      self.bootme(options)
    elsif options[:asynchronous] or options[:solo] or classname == Scenario
      debug "queuing - #{self.class.to_s} #{self.name} for boot"
      self.set_queued_boot
      self.delay(queue: self.class.to_s.downcase).bootme(options)
    else
      if not self.bootme(options)
        return false
      end
    end
    
    true
  end

  def bootme(options = {})
    self.set_booting
    if not self.send("provider_boot_#{self.class.to_s.downcase}", options)
      return false
    end
    true
  end

  def unboot(options = {})
    classname = self.class
    if classname == Scenario
      if not (self.booted? or self.partially_booted? or self.boot_failed? or self.unboot_failed? or self.paused?)
        errors.add(:boot, "#{self.class} must be booted or partially booted or have a error to uboot")
        return false
      end
    else
      if self.driver_id == nil
        self.set_stopped
        return true
      end
    # elsif not (self.booted? or self.boot_failed? or self.unboot_failed? or self.paused?)
    #   errors.add(:boot, "#{self.class} must be booted, have an error, or be paused to unboot")
    #   return false
    end

    if not options[:dependents]
      if classname == Cloud
        if not self.subnets_stopped?
          errors.add(:boot, "#{self.class}s subnets must be stopped")
          return false
        end
      elsif classname == Subnet
        if not self.instances_stopped?
          errors.add(:boot, "#{self.class}s instances must be stopped")
          return false
        end
      end
    end

    self.debug_unbooting
    
    if options[:debug]
      self.bootme(options)
    elsif options[:asynchronous] or options[:solo] or classname == Scenario
      debug "queuing - #{self.class.to_s} #{self.name} for unboot"
      self.set_queued_unboot
      self.delay(queue: self.class.to_s.downcase).unbootme(options)
    else
      if not self.unbootme(options)
        return false
      end
    end

    true
  end

  def unbootme(options = {})
    self.set_unbooting
    if not self.send("provider_unboot_#{self.class.to_s.downcase}", options)
      return false
    end
    true
  end

  def unboot_error(error)
    self.set_unboot_failed
    debug(error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n"));
    self.scenario.set_unboot_failed
  end

  def pause
    if not (self.class == Instance or self.class == Scenario)
      return
    end

    if not self.booted?
      errors.add(:boot, "must be booted to pause")
      return
    end
    
    if self.class == Scenario
      self.set_pausing
      self.delay(queue: self.class.to_s.downcase).send("provider_pause_#{self.class.to_s.downcase}")
    else
      self.send("provider_pause_#{self.class.to_s.downcase}")
    end
  end

  def start
    if not (self.class == Instance or self.class == Scenario)
      return
    end

    if not self.paused?
      errors.add(:boot, "must be paused to start")
      return
    end

    if self.class == Scenario
      self.set_starting
      self.delay(queue: self.class.to_s.downcase).send("provider_start_#{self.class.to_s.downcase}")
    else
      self.send("provider_start_#{self.class.to_s.downcase}")
    end
  end

  #############################################################
  #  Status set and get

  def set_stopped
    self.update_attribute(:status, :stopped)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_paused
    self.update_attribute(:status, :paused)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_pausing
    self.update_attribute(:status, :pausing)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_starting
    self.update_attribute(:status, :starting)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_queued_boot
    self.update_attribute(:status, :queued_boot)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_queued_unboot
    self.update_attribute(:status, :queued_unboot)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_booting
    self.update_attribute(:status, :booting)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_unbooting
    self.update_attribute(:status, :unbooting)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_boot_failed
    self.update_attribute(:status, :boot_failed)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_unboot_failed
    self.update_attribute(:status, :unboot_failed)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_booted
    self.update_attribute(:status, :booted)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_partially_booted
    self.update_attribute(:status, :partially_booted)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_partially_unbooted
    self.update_attribute(:status, :partially_unbooted)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_failure
    self.update_attribute(:status, :failure)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_partially_booted_with_failure
    self.update_attribute(:status, :partially_booted_with_failure)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def set_partially_unbooted_with_failure
    self.update_attribute(:status, :partially_unbooted_with_failure)
    if self.class != Scenario
      self.scenario.check_status
    end
  end

  def is_failed?
    return self.status == "unboot_failed" || self.status == "boot_failed"
  end

  def queued?
    return (self.queued_boot? or self.queued_unboot?)
  end

  # Polls the state in database, waiting to yield to given block until self is booted?
  # If self is not booted?, calls provider_check_status for self.
  # @param block The block to execute when self.booted?
  def run_when_booted
    until self.booted?
      self.reload
      sleep 1
      classname = self.class.to_s.downcase
      self.run_provider_method("#{classname}_check_status")
    end
    yield
  end

  def wait_until_booted
    until ['booted', 'boot_failed'].include? self.status
      sleep 1
    end
    if self.status == "boot_failed"
      return "error"
    end
    return nil
  end

  def wait_until_stopped
    until ['stopped', 'unboot_failed'].include? self.status
      sleep 1
    end
    if self.status == "unboot_failed"
      return "error"
    end
    return nil
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
    self.send("#{Settings.driver}_#{provider_method}".to_sym, *args)
  end
end
