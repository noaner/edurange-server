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
    enum status: [:stopped, :queued_boot, :queued_unboot, :booting, :booted, :failure, :boot_failed, :unboot_failed, :unbooting, :stopping, :partially_booted, :partially_booted_with_failure, :partially_unbooted, :partially_unbooted_with_failure]
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
    update_attributes(log: '')
  end

  def boot_error(error)

    self.set_boot_failed
    debug(error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n"));
    self.save
    self.reload

    # time = Time.new
    # File.open("#{Rails.root}/log/boot.#{scenario.id}-#{scenario.name}.log", 'a') do |f|
      # f.puts "\n"
      # f.puts error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
      # f.puts "\n"
    # end
  end

  def boot(options = {})
    classname = self.class.to_s.downcase
    puts classname
    self.send("provider_boot_#{classname}", options)
  end

  def unboot(options = {})
    classname = self.class.to_s.downcase
    puts classname
    self.send("provider_unboot_#{classname}", options)
  end

  def unboot_error(error)
    self.set_unboot_failed
    self.save
    debug(error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n"));
  end


  #############################################################
  #  Status set and get

  def set_stopped
    self.update_attribute(:status, :stopped)
  end

  def set_queued_boot
    self.update_attribute(:status, :queued_boot)
  end

  def set_queued_unboot
    self.update_attribute(:status, :queued_unboot)
  end

  def set_booting
    self.update_attribute(:status, :booting)
  end

  def set_unbooting
    self.update_attribute(:status, :unbooting)
  end

  def set_boot_failed
    self.update_attribute(:status, :boot_failed)
  end

  def set_unboot_failed
    self.update_attribute(:status, :unboot_failed)
  end

  def set_booted
    self.update_attribute(:status, :booted)
  end

  def set_partially_booted
    self.update_attribute(:status, :partially_booted)
  end

  def set_partially_unbooted
    self.update_attribute(:status, :partially_unbooted)
  end

  def set_failure
    self.update_attribute(:status, :failure)
  end

  def set_partially_booted_with_failure
    self.update_attribute(:status, :partially_booted_with_failure)
  end

  def set_partially_unbooted_with_failure
    self.update_attribute(:status, :partially_unbooted_with_failure)
  end

  def is_failed?
    return self.status == "unboot_failed" || self.status == "boot_failed"
  end

  def queued?
    return true if self.queued_boot? or self.queued_unboot?
    false
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
