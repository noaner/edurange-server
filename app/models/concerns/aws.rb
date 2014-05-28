require 'active_support'
module Aws
  extend ActiveSupport::Concern

  # AWS::Scenario methods
  def aws_scenario_boot

  end
  def aws_scenario_final_setup
    debug "=== Final setup."
    # Anything that needs to be performed when the environment is 100% up.

    # Currently assumes there is only one NAT.
    Subnet.all.each do |subnet|
      @route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: subnet.cloud.driver_id)
      debug "[x] AWS_Driver::create_route_table #{@route_table}"
      subnet.aws_subnet_driver_object.route_table = @route_table
      if subnet.internet_accessible
        # Route traffic straight to internet, avoid the NAT
        debug "NOTE: Subnet.all.each. Subnet #{subnet} adding route to igw"
        @route_table.create_route("0.0.0.0/0", { internet_gateway: subnet.cloud.aws_cloud_igw} )
      else
        debug "NOTE: Subnet.all.each. Subnet #{subnet} adding route to NAT"
        # Find the NAT instance
        @route_table.create_route("0.0.0.0/0", { instance: Instance.where(internet_accessible: true).first.driver_id } )
      end
    end
    # Hardcoded firewall rules - TODO
    Cloud.first.aws_cloud_driver_object.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
    Cloud.first.aws_cloud_driver_object.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
    Cloud.first.aws_cloud_driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
    Cloud.first.aws_cloud_driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
    # TODO -- SECURITY -- delayed job in 20 min disable firewall.
    Cloud.first.aws_cloud_driver_object.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
  end

  def aws_upload_scoring_url
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-scoring']
    s3.buckets.create('edurange-scoring') unless bucket.exists?
    self.scoring_url = bucket.objects[self.uuid + "-scoring"].url_for(:write, expires: 10.hours, :content_type => 'text/plain').to_s
    self.save
  end

  def aws_upload_scoring_page
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-scoring']
    s3.buckets.create('edurange-scoring') unless bucket.exists?
    self.scoring_page = bucket.objects[self.uuid + "-scoring"].url_for(:read, expires: 10.hours).to_s
    self.save
  end

  # AWS::Cloud methods
  def aws_cloud_igw
    self.aws_cloud_driver_object.internet_gateway
  end
  def aws_cloud_driver_object
    AWS::EC2::VPCCollection.new[self.driver_id]
  end
  def aws_cloud_check_status
    if self.aws_cloud_driver_object.state == :available
      self.status = "booted"
      self.save!
    end
  end
  def aws_cloud_boot
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
      self.aws_cloud_driver_object.internet_gateway = @igw
    end
  end

  # AWS::Subnet methods
  def aws_subnet_nat?
    @internet_accessible
  end
  def aws_subnet_check_status
    if self.aws_subnet_driver_object.state == :available
      self.status = "booted"
      self.save!
    end
  end
  def aws_subnet_boot
    self.driver_id = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id).id
    self.save
    debug self.inspect
    debug "[x] AWS_Driver::create_subnet #{self.driver_id}"
    sleep 5
    run_when_booted do
      self.status = "booted"
      self.save!
    end
  end
  def aws_subnet_allow_traffic(cidr, options)
    instances.each do |instance|
      instance.allow_traffic(cidr, options)
    end
  end
  def aws_subnet_closest_nat_instance
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
  def aws_subnet_driver_object
    AWS::EC2::SubnetCollection.new[self.driver_id]
  end

  # AWS::Instance methods
  def aws_instance_nat?
    @internet_accessible
  end
  def aws_instance_public_ip
    return false unless self.driver_id
    return false unless self.internet_accessible
    @public_ip ||= self.aws_instance_driver_object.public_ip_address
  end
  def aws_instance_boot
    debug "Called aws_boot in instance!"
    debug "AWS_Driver::provider_boot - instance"
    instance_template = InstanceTemplate.new(self)
    debug "AWS_Driver::InstanceTemplate.new"

    cookbook_text = instance_template.generate_cookbook
    debug "AWS_Driver::instance_template.generate_cookbook"
    self.aws_instance_upload_cookbook(cookbook_text)
    debug "AWS_Driver::self.aws_instance_upload_cookbook"

    self.aws_upload_scoring_url
    debug "AWS_Driver::self.upload_scoring_url"

    self.aws_upload_scoring_page
    debug "AWS_Driver::self.upload_scoring_page"

    cloud_init = instance_template.generate_cloud_init(self.cookbook_url)
    debug "AWS_Driver::self.generate cloud init"
    debug self.cookbook_url
    debug self.scoring_url + "test scoring url"
    debug self.scoring_page + "test scoring page"

    # self.public_ip = self.aws_instance_public_ip
    debug "Setting public_ip" + "test public ip"


    sleep 2 until self.subnet.booted?
    debug "subnet booted"
    self.driver_id = AWS::EC2::InstanceCollection.new.create(
                                                             image_id: self.aws_instance_ami_id, # ami_id string of os image
                                                             private_ip_address: self.ip_address, # ip string
                                                             key_name: Settings.ec2_key, # keypair string
                                                             user_data: cloud_init, # startup data
                                                             subnet: self.subnet.driver_id).id # subnet id for where this instance goes

    # Get an EC2 client object to set the instance tags
    ec2 = AWS::EC2.new
    ec2.client.create_tags(:resources => [self.driver_id], :tags => [
                                                                     { :key => 'Name', :value => "#{self.subnet.cloud.scenario.name} - #{self.name}" }
                                                                    ])
    self.save
    debug self.inspect

    if self.internet_accessible
      run_when_booted do
        eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
        debug "AWS_Driver:: Allocated EIP #{eip}"
        self.aws_instance_driver_object.associate_elastic_ip eip
        self.aws_instance_driver_object.network_interfaces.first.source_dest_check = false # Set first NIC (assumption) to not check source/dest. Required to accept other machines' packets
      end
    end
    add_progress
  end
  def aws_instance_driver_object
    AWS::EC2::InstanceCollection.new[self.driver_id]
  end
  def aws_instance_check_status
    if self.aws_instance_driver_object.status == :running
      self.status = "booted"
      self.save!
    end
  end
  def aws_instance_ami_id
    if self.os == 'ubuntu'
      'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
    elsif self.os == 'nat'
      'ami-51727d38' # Private NAT image with chef and deps, updates etc.
    end
  end
  def aws_instance_upload_cookbook(cookbook_text)
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange']
    unless bucket.exists?
      s3.buckets.create('edurange')
    end
    self.uuid = `uuidgen`
    bucket.objects[uuid].write(cookbook_text)
    self.cookbook_url = bucket.objects[self.uuid].url_for(:read, expires: 10.hours).to_s
    self.save
  end
end
