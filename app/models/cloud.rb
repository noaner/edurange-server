class Cloud < ActiveRecord::Base
  enum status: [:stopped, :booting, :booted]
  validates_presence_of :cidr_block, :scenario

  belongs_to :scenario
  has_many :subnets, dependent: :delete_all
  def boot
    if self.stopped?
      self.status = "booting"
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting cloud..."
      
      # Boot
      self.provider_boot
      add_progress
      
      # Boot Subnets
      self.subnets.each { |subnet| subnet.boot }
    end
  end
  def provider_boot
    self.send("#{Settings.driver}_boot".to_sym)
  end
  def provider_check_status
    self.send("#{Settings.driver}_check_status".to_sym)
  end
  def igw
    self.driver_object.internet_gateway
  end
  def driver_object
    AWS::EC2::VPCCollection.new[self.driver_id]
  end
  def aws_check_status
    if self.driver_object.state == :available
      self.status = "booted"
      self.save!
    end
  end
  def aws_boot
    debug "Called aws_boot!"
    debug self.inspect
    debug "AWS_Driver::provider_boot - cloud"
    # Create VPC
    if self.cidr_block.nil?
      raise "Tried to create Cloud without enough information."
    end

    self.driver_id = AWS::EC2.new.vpcs.create(self.cidr_block).id
    self.save
    debug "[x] AWS_Driver::create_vpc #{@driver_id}"

    @igw = AWS::EC2.new.internet_gateways.create
    debug "[x] AWS_Driver::create_internet_gateway #{@igw.internet_gateway_id}"
    run_when_booted do
      self.driver_object.internet_gateway = @igw
    end
  end
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
      self.provider_check_status
    end
    yield
  end
  def add_progress
    PrivatePub.publish_to "/scenarios/#{self.scenario.id}", cloud_progress: 1
  end
  def debug(message)
    log = self.scenario.log
    self.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
end
