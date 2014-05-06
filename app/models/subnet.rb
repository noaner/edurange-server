class Subnet < ActiveRecord::Base
  validates_presence_of :cidr_block, :cloud

  belongs_to :cloud
  
  has_many :instances, dependent: :delete_all

  validate :cidr_block_must_be_within_cloud
  enum status: [:stopped, :booting, :booted]
  def cidr_block_must_be_within_cloud
    # TODO check cidr block within cloud
    true
  end
  def boot
    if self.stopped?
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting subnet..."
      
      # Boot
      self.provider_boot
      self.status = "booted"
      self.save!
      add_progress
      
      # Boot Instances
      self.instances.each { |instance| instance.boot }
    end
  end
  def provider_check_status
    self.send("#{Settings.driver}_check_status".to_sym)
  end
  def aws_check_status
    self.driver_object.state == :available
  end
  def driver_object
    AWS::EC2::SubnetCollection.new[self.driver_id]
  end
  def closest_nat_instance
    # Finds the NAT instance closest to us. TODO. Currently just assumes there's one
    Instance.all.each do |instance|
      if instance.internet_accessible
        # Found our NAT
        if instance.booted?
          return instance.driver_id
        else
          instance.provider_boot
          return instance.driver_id
        end
      end
    end
  end
  def allow_traffic(cidr, options)
    instances.each do |instance|
      instance.allow_traffic(cidr, options)
    end
  end

  def provider_boot
    self.send("#{Settings.driver}_boot".to_sym)
  end
  def aws_boot
    self.driver_id = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id).id
    self.save
    debug self.inspect
    debug "[x] AWS_Driver::create_subnet #{self.driver_id}"
    sleep 5
    run_when_booted do
      self.status = "booted"
      self.save!
    end
    def run_when_booted
      until self.booted?
        self.reload
        sleep 2
        provider_check_status
      end
      yield
    end
    handle_asynchronously :run_when_booted
    def add_progress
      debug "Adding progress to subnet"
      PrivatePub.publish_to "/scenarios/#{self.cloud.scenario.id}", subnet_progress: 1
    end
    def debug(message)
      log = self.cloud.scenario.log
      self.cloud.scenario.update_attributes(log: log + message + "\n")
      PrivatePub.publish_to "/scenarios/#{self.cloud.scenario.id}", log_message: message
    end
  end
end
