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
    enum status: [:stopped, :booting, :booted, :failed, :boot_failed, :unboot_failed, :unbooting, :stopping, :broken, :fixing]
  end

  # def max_attempts; 0; end

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

  def boot
    classname = self.class.to_s.downcase
    puts classname

    self.set_booting
    self.clear_log
    self.send("provider_boot_#{classname}")
    # self.delay.send("provider_boot_#{classname}")

  end
  # handle_asynchronously :boot, priority: 20

  def unboot_error(error)
    self.set_boot_failed
    self.save
    debug(error.class.to_s + ' - ' + error.message.to_s);
  end

  def unboot
    classname = self.class.to_s.downcase
    puts classname
    self.set_unbooting
    self.send("provider_unboot_#{classname}")
  end
  # handle_asynchronously :boot, priority: 20

  ## Status set and get
  # set status

  def set_stopped
    self.status = "stopped"
    self.save!
  end

  def set_stopping
    self.status = "stopping"
    self.save!
  end

  def set_booting
    self.status = "booting"
    self.save!
  end

  def set_boot_failed
    self.status = :boot_failed
    self.save!
  end

  def set_booted
    self.status = "booted"
    self.save!
  end

  def set_unbooting
    self.status = "unbooting"
    self.save!
  end

  def set_failed
    self.status = "failed"
    self.save!
  end

  def set_unboot_failed
    self.status = "unboot_failed"
    self.save!
  end

  # get status

  def stopped?
    return self.status == :stopped
  end

  def booted?
    return self.status == :booted
  end

  def boot_failed?
    return self.status == :boot_failed
  end

  def is_failed?
    return self.status == "unboot_failed" || self.status == "boot_failed"
  end

  def booting?
    return self.status == "booting"
  end

  def unbooting?
    return self.status == "unbooting"
  end

  def boot_failed?
    return self.status == "boot_failed"
  end

  def unboot_failed?
    return self.status == "boot_failed"
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
    puts "\nMethod Miss\n"
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
