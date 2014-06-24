# This file contains the implementation of the AWS API calls. They are implemented
# as hooks, called dynamically by the {Provider} concern when {Scenario}, {Cloud}, {Subnet}, and {Instance} are booted.
# @see Provider#boot
require 'active_support'
module Aws
  extend ActiveSupport::Concern

  # This method does nothing, but must be defined as the hook is called regardless
  # @return [nil]
  def aws_scenario_boot
  end

  # This method loops through each subnet and creates a route table for it.
  # If the subnet is internet accessible, it creates a route to the IGW. If not, it routes to the NAT.
  # Additionally, it has some hardcoded firewall rules which restrict traffic. They should be fixed eventually.
  # @see Provider#boot
  # @return [nil]
  def aws_scenario_final_setup
    debug "=== Final setup."
    # Anything that needs to be performed when the environment is 100% up.

    # Currently assumes there is only one NAT. TODO
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


  def aws_scenario_upload_scoring_pages
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-scoring']
    name = self.name + "-" + self.uuid + "-scoring-pages"
    self.update(scoring_pages: bucket.objects[name].url_for(:read, expires: 10.hours).to_s)
  end

  def aws_scenario_write_to_scoring_pages
    AWS::S3.new.buckets['edurange-scoring'].objects[self.name + "-" + self.uuid + "-scoring-pages"].write(self[:scoring_pages_content])
  end

  def aws_scenario_upload_answers
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-answers']
    s3.buckets.create('edurange-answers') unless bucket.exists?
    object = bucket.objects[self.name]
    object.write(self.answers)
    self.update(answers_url: object.url_for(:read, expires: 10.hours).to_s)
  end

  def aws_upload_scoring_url
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-scoring']
    s3.buckets.create('edurange-scoring') unless bucket.exists?
    name = self.uuid + "-scoring-" + self.name
    bucket.objects[name].write("# put your answers here")
    self.update(scoring_url: bucket.objects[name].url_for(:write, expires: 10.hours, :content_type => 'text/plain').to_s)
  end

  def aws_upload_scoring_page
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange-scoring']
    s3.buckets.create('edurange-scoring') unless bucket.exists?
    self.update(scoring_page: bucket.objects[self.uuid + "-scoring"].url_for(:read, expires: 10.hours).to_s)
  end

  # AWS::Cloud methods
  def aws_cloud_igw
    self.aws_cloud_driver_object.internet_gateway
  end

  # Fetches the {Cloud}'s AWS Virtual Private Cloud object
  # @return [AWS::EC2::VPCCollection]
  def aws_cloud_driver_object
    AWS::EC2::VPCCollection.new[self.driver_id]
  end

  # Fetches the {Cloud}'s AWS Virtual Private Cloud object's state
  # to see if it is booted.
  # @return [Boolean] if {Cloud} is booted
  def aws_cloud_check_status
    if self.aws_cloud_driver_object.state == :available
      self.update(status: "booted")
    end
  end

  # Boots {Cloud}, and all of its {Subnet Subnets}.
  # Creates a AWS::EC2::VPC object with Subnet's cidr_block
  # @return [nil]
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

  # @return [Boolean] Whether or not the {Subnet} is internet_accessible
  def aws_subnet_nat?
    @internet_accessible
  end
 
  # @return [Boolean] Whether or not the {Subnet} is booted
  def aws_subnet_check_status
    if self.aws_subnet_driver_object.state == :available
      self.update(status: "booted")
    end
  end

  # Boots {Subnet}, and all of its {Instance Instances}.
  # Creates a AWS::EC2::Subnet object, taking Subnet's `cidr_block` and the `VPC ID` of the {Cloud} the {Subnet} resides in.
  # @return [nil]
  def aws_subnet_boot
    self.driver_id = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id).id
    self.save
    debug self.inspect
    debug "[x] AWS_Driver::create_subnet #{self.driver_id}"
    sleep 5
    run_when_booted do
      self.update(status: "booted")
    end
  end 
  
  # Calls #aws_instance_allow_traffic on all of {Subnet}'s {Instance Instances}
  # @param cidr The cidr block to allow traffic to
  # @param options The options to pass. Currently undefined
  # @return [nil]
  def aws_subnet_allow_traffic(cidr, options)
    instances.each do |instance|
      instance.aws_instance_allow_traffic(cidr, options)
    end
  end
  
  # Calls {Provider#boot} on the first {#aws_instance_nat?} {Instance}
  # @return [String] The AWS Instance ID corresponding to the NAT Instance
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
  
  # Fetches {Subnet}'s AWS Subnet Object
  # @return [AWS::EC2::Subnet]
  def aws_subnet_driver_object
    AWS::EC2::SubnetCollection.new[self.driver_id]
  end

  # @return [Boolean] Whether or not the {Instance} is internet_accessible
  def aws_instance_nat?
    @internet_accessible
  end
  
  # Currently does nothing, as we have hardcoded rules defined.
  # @see #aws_scenario_final_setup
  # @return [nil]
  def aws_instance_allow_traffic
  end

  # Uses memoization to cache this lookup for faster page renders
  # @return [String] The public IP address belonging to {Instance}'s AWS Instance Object
  def aws_instance_public_ip
    return false unless self.driver_id
    return false unless self.internet_accessible
    @public_ip ||= self.aws_instance_driver_object.public_ip_address
  end

  # Boots {Instance}, generating required cookbooks and startup scripts.
  # This method largely defers to {InstanceTemplate} in order to generate shell scripts and
  # chef scripts to configure each instance.
  # Additionally, it uploads and stores the cookbook_url, which is generated by calling {#aws_instance_upload_cookbook}
  # @return [nil]
  def aws_instance_boot
    debug "Called aws_boot in instance!"
    debug "AWS_Driver::provider_boot - instance"
    instance_template = InstanceTemplate.new(self)
    debug "AWS_Driver::InstanceTemplate.new"

    cookbook_text = instance_template.generate_cookbook
    debug "AWS_Driver::instance_template.generate_cookbook"
    self.aws_instance_upload_cookbook(cookbook_text)
    debug "AWS_Driver::self.aws_instance_upload_cookbook"

    cloud_init = instance_template.generate_cloud_init(self.cookbook_url)
    debug "AWS_Driver::self.generate cloud init"

    debug self.cookbook_url

    # self.public_ip = self.aws_instance_public_ip
    debug "Setting public_ip"

    sleep 2 until self.subnet.booted?
    debug "subnet booted"
    self.driver_id = AWS::EC2::InstanceCollection.new.create(
                                                             image_id: self.aws_instance_ami_id, # ami_id string of os image
                                                             private_ip_address: self.ip_address, # ip string
                                                             key_name: Settings.ec2_key, # keypair string
                                                             user_data: cloud_init, # startup data
                                                             subnet: self.subnet.driver_id).id # subnet id for where this instance goes

    self.save
    debug self.inspect    
    # Get an EC2 client object to set the instance tags
    
    #sleep 8 while AWS::EC2.new.instances[self.driver_id].status == :pending

    #ec2 = AWS::EC2.new    
    #ec2.client.create_tags(:resources => [self.driver_id], :tags => [{ :key => 'Name', :value => "#{self.subnet.cloud.scenario.name} - #{self.name}" }])


    if self.internet_accessible
      run_when_booted do
        eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
        until eip.exists?
          sleep 2
          debug "Polling EIP..."
        end

        debug "AWS_Driver:: Allocated EIP #{eip}"
        self.aws_instance_driver_object.associate_elastic_ip eip
        self.aws_instance_driver_object.network_interfaces.first.source_dest_check = false # Set first NIC (assumption) to not check source/dest. Required to accept other machines' packets
      end
    end
    add_progress
  end
  # Fetches the {Instance}'s AWS Instance Object
  # @return [AWS::EC2::InstanceCollection]
  def aws_instance_driver_object
    AWS::EC2::InstanceCollection.new[self.driver_id]
  end

  # @return [Boolean} Whether or not {Instance}'s AWS Instance Object's status is booted.
  def aws_instance_check_status
    self.update(status: "booted") if self.aws_instance_driver_object.status == :running
  end

  # @return [String] the string corresponding to an AMI image ID for the OS of the {Instance}
  def aws_instance_ami_id
    if self.os == 'ubuntu'
      'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
    elsif self.os == 'nat'
      'ami-51727d38' # Private NAT image with chef and deps, updates etc.
    end
  end
  
  # This uploads our chef cookbook into S3, and gets us a url. This is given to the shell script
  # which sets a cron job to download and run the chef recipe.
  # @param cookbook_text The text to upload to S3  
  # @return [String] A URL generated from S3 pointing to our text
  def aws_instance_upload_cookbook(cookbook_text)
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange']
    s3.buckets.create('edurange') unless bucket.exists?
    bucket.objects[uuid].write(cookbook_text)
    self.update(cookbook_url: bucket.objects[uuid].url_for(:read, expires: 10.hours).to_s)
  end
end
