class Scenario < ActiveRecord::Base
  attr_accessor :template # For picking a template when creating a new scenario
  has_many :clouds, dependent: :delete_all
  validates_presence_of :name, :description
  enum status: [:stopped, :booting, :booted]
  # provides .stopped?, .booting?, .booted?, and .status (ret "stopped", "booting", or "booted")
  def boot
    if self.stopped?
      self.status = "booting"
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting scenario..."
      
      # Boot Clouds
      self.clouds.each { |cloud| cloud.boot }
      
      # Final Setup
      self.final_setup
      self.status = "booted"
      self.save!
    end
  end
  def aws_final_setup
    debug "=== Final setup."
    # Anything that needs to be performed when the environment is 100% up.

    # Currently assumes there is only one NAT.
    Subnet.all.each do |subnet|
      @route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: subnet.cloud.driver_id)
      debug "[x] AWS_Driver::create_route_table #{@route_table}"
      subnet.driver_object.route_table = @route_table
      if subnet.internet_accessible
        # Route traffic straight to internet, avoid the NAT
        debug "NOTE: Subnet.all.each. Subnet #{subnet} adding route to igw"
        @route_table.create_route("0.0.0.0/0", { internet_gateway: subnet.cloud.igw} )
      else
        debug "NOTE: Subnet.all.each. Subnet #{subnet} adding route to NAT"
        # Find the NAT instance
        @route_table.create_route("0.0.0.0/0", { instance: Instance.where(internet_accessible: true).first.driver_id } )
      end
    end
    Cloud.first.driver_object.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
    Cloud.first.driver_object.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
    Cloud.first.driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
    Cloud.first.driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
    Cloud.first.driver_object.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
  end
  def final_setup
    self.send("#{Settings.driver}_final_setup".to_sym)
  end

  def debug(message)
    log = self.log
    self.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.id}", log_message: message
  end
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
    end
    yield
  end
  handle_asynchronously :run_when_booted
end
