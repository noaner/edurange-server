# This file contains the implementation of the AWS API calls. They are implemented
# as hooks, called dynamically by the {Provider} concern when {Scenario}, {Cloud}, {Subnet}, and {Instance} are booted.
# @see Provider#boot
require 'active_support'
module Aws
  extend ActiveSupport::Concern

  def max_attempts; 0; end

  # This method does nothing, but must be defined as the hook is called regardless
  # @return [nil]
  # def aws_scenario_boot
  # end

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
    self.get_instances.each do |instance|
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
    bucket = s3.buckets[Settings.bucket_name]
    s3.buckets.create(Settings.bucket_name) unless bucket.exists?
    bucket.objects[uuid].write(cookbook_text)
    self.update(cookbook_url: bucket.objects[uuid].url_for(:read, expires: 10.hours).to_s)
  end

  #############################################################
  #  Boot

  def aws_boot_error(scenario, error)
    # self.status = "boot_failed"
    # self.save
    scenario.status = "boot_failed"
    scenario.save

    PrivatePub.publish_to "/scenarios/#{scenario.id}", scenario_status: "boot_failed"

    debug '\n---- Boot ERROR ---' + error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
    time = Time.new
    File.open("#{Rails.root}/log/boot.#{scenario.id}-#{scenario.name}.log", 'a') do |f|
      f.puts "\n"
      f.puts error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
      f.puts "\n"
    end
  end

  # Boots {Instance}, generating required cookbooks and startup scripts.
  # This method largely defers to {InstanceTemplate} in order to generate shell scripts and
  # chef scripts to configure each instance.
  # Additionally, it uploads and stores the cookbook_url, which is generated by calling {#aws_instance_upload_cookbook}
  # @return [nil]
  def aws_boot_instance_new(instance)
    debug "   booting - Instance #{instance.name}"

    instance_template = InstanceTemplate.new(instance)
    cookbook_text = instance_template.generate_cookbook
    instance.aws_instance_upload_cookbook(cookbook_text)
    cloud_init = instance_template.generate_cloud_init(instance.cookbook_url)

    # get ami based on OS
    if instance.os == 'ubuntu'
      aws_instance_ami = 'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
    elsif instance.os == 'nat'
      aws_instance_ami = 'ami-51727d38' # Private NAT image with chef and deps, updates etc.
    end

    # create EC2 Instance
    tries = 0
    debug "    creating - EC2 Instance"
    begin
      ec2instance = AWS::EC2::InstanceCollection.new.create(
        image_id: aws_instance_ami, # ami_id string of os image
        private_ip_address: instance.ip_address, # ip string
        key_name: Settings.ec2_key, # keypair string
        user_data: cloud_init, # startup data
        instance_type: "t1.micro",
        subnet: instance.subnet.driver_id
      )
    rescue AWS::EC2::Errors::InvalidParameterCombination => e 
      # wrong instance type
      raise
      return
    rescue AWS::EC2::Errors::InvalidSubnetID::NotFound => e
      tries += 1
      if tries > 3
        raise
        return
      end
      sleep 2
      retry
    rescue
      raise
      return
    end
    debug "    [x] created - EC2 Instance #{ec2instance.id}"
    instance.add_progress 1

    # set instance driver_id
    debug "    assigning - Instance #{instance.name} driver_id"
    begin
      instance.driver_id = ec2instance.id
    rescue => e
      raise
      return
    end
    instance.save
    debug "    [x] assigned - Instance #{instance.name} driver_id"


    # wait for Instance to become available
    tries = 0
    begin
      cnt = 0
      until ec2instance.status == :running
        debug "    waiting for - EC2 Instance #{instance.driver_id} to become available"
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          aws_boot_error(instance.subnet.cloud.scenario, $!)
          instance.set_boot_failed
          return
        end
      end
    rescue AWS::EC2::Errors::InvalidInstanceID
      if tries > 5
        raise
        return
      end
      tries += 1
      sleep 3
      retry
    rescue
      raise
      return
    end
    debug "    [x] EC2 Istance #{instance.driver_id} is now available"

    # for Internet Accessible instances 
    if instance.internet_accessible

      # create Elastip IP
      debug "    creating - EC2 Elastic IP"
      begin 
        ec2eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      rescue => e
        raise
        return
      end
      debug "    [x] created - EC2 Elastic IP"

      # wait for EIP to become available
      cnt = 0
      until ec2eip.exists?
        debug "    waiting for - EC2 Elastic IP #{instance.driver_id} to become available"
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          aws_boot_error(instance.subnet.cloud.scenario, $!)
          return
        end
      end
      debug "    [x] EC2 Elastic IP #{ec2eip.public_ip} is now available"

      # associate instance with EIP
      debug "    associating - EC2 Elastip IP with EC2 Instance #{ec2instance.id}"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
      rescue => e
        raise
        return
      end
      debug "    [x] associated - EC2 Elastip IP with EC2 Instance #{ec2instance.id}"

      # accept packets coming in
      debug "    accepting - EC2 Instance NIC packets, disabe source dest checks"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
        ec2instance.network_interfaces.first.source_dest_check = false
      rescue
        raise
        return
      end
      debug "    [x] accepted - EC2 Instance NIC packets"
    end

    begin
      PrivatePub.publish_to "/scenarios/#{instance.subnet.cloud.scenario.id}", public_ip: ec2instance.public_ip_address
    rescue
      raise
      return
    end

    instance.set_booted
    instance.save
    debug "    [x] booted - Instance #{instance.name}"
  end

  # Boots {Subnet}, and all of its {Instance Instances}.
  # Creates a AWS::EC2::Subnet object, taking Subnet's `cidr_block` and the `VPC ID` of the {Cloud} the {Subnet} resides in.
  # @return [nil]
  def aws_boot_subnet_new(subnet)
    debug "  booting - Subnet #{subnet.id}"

    # create Subnet
    debug "   creating - EC2 Subnet"
    begin
      ec2subnet = AWS::EC2::SubnetCollection.new.create(subnet.cidr_block, vpc_id: subnet.cloud.driver_id)
    rescue => e
      raise
      return
    end
    debug "   [x] created - EC2 Subnet #{subnet.id}"
    subnet.add_progress 1

    # set driver_id
    debug "   assigning - Subnet #{subnet.id} driver_id"
    begin
      subnet.driver_id = ec2subnet.id
    rescue => e
      raise
      return
    end
    subnet.save
    debug "   [x] assigned - Subnet #{subnet.id} driver_id"

    # wait till Subnet is available
    begin 
      cnt = 0
      until ec2subnet.state == :available
        debug "   waiting for - EC2 Subnet #{subnet.driver_id} to become available"
        sleep 1
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          subnet.set_boot_failed
          return
        end
      end
    rescue AWS::EC2::Errors::InvalidSubnetID::NotFound
      retry
    rescue
      raise
      return
    end
    debug "   EC2 Subnet #{subnet.driver_id} is now available"

    subnet.set_booted
    subnet.save
    debug "   [x] booted - Subnet #{subnet.driver_id}"

    subnet.instances.select{ |i| !i.driver_id}.each do |instance|
      begin
        aws_boot_instance_new(instance)
      rescue
        raise
        return
      end
    end
  end

  # Boots {Cloud}, and all of its {Subnet Subnets}.
  # Creates a AWS::EC2::VPC object with Subnet's cidr_block
  # @return [nil]
  def aws_scenario_boot_cloud_new(cloud)
    debug " booting Cloud #{cloud.id}"

    # create vpc
    debug "  creating VPC"
    begin
      ec2vpc = AWS::EC2.new.vpcs.create(cloud.cidr_block)
      rescue
        raise
      return
    end
    debug "  [x] created VPC #{ec2vpc.id}"
    cloud.add_progress 1

    # assign driver_id
    debug "  assigning - VPC #{cloud.id} driver_id"
    begin
      cloud.driver_id = ec2vpc.id
    rescue
      raise
      return
    end
    cloud.save
    debug "  [x] assigned - VPC #{cloud.id} driver_id"

    # create internet gateway
    debug "  creating - Internet Gateway"
    begin
      ec2vpc.internet_gateway = AWS::EC2.new.internet_gateways.create
    rescue
      raise
      return
    end
    debug "  [x] created - Internet Gateway"

    # wait for VPC to become available, erorr if timeout
    begin
      cnt = 0
      until ec2vpc.state == :available
        debug "  waiting for - VPC #{cloud.driver_id} to become available"
        sleep 1
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          # cloud.set_boot_failed
          return
        end
      end
    rescue
      raise
      return
    end
    "  [x] VPC #{cloud.driver_id} is now available"

    cloud.set_booted
    cloud.save
    debug "  [x] booted - Cloud #{cloud.driver_id}"

    # boot clouds Subnets
    cloud.subnets.each do |subnet|
      aws_boot_subnet_new(subnet)
    end
  end

  def aws_scenario_boot_private_new

    debug "booting Scenario #{self.name}"
    self.clouds.select{|c| !c.driver_id}.each do |cloud|
      begin
        aws_scenario_boot_cloud_new(cloud)
      rescue => e
        raise
        return
      end
    end

    debug "getting - EC2 Cloud #{self.clouds.first.driver_id}"
    begin
      ec2cloud = AWS::EC2.new.vpcs[self.clouds.first.driver_id]
    rescue => e
      raise
      return
    end
    debug "[x] got - EC2 Cloud #{self.clouds.first.driver_id}"

    # Route Tables and Firewall Rules
    # Loop through each subnet and create a route table for it, if subnet is internet accessible, create a route to the Internet Gateway, else create a route to the NAT.
    self.get_subnets.each do |subnet|

      # create Route table
      debug "creating - EC2 RouteTable for #{subnet.driver_id}"
      begin
        ec2route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: subnet.cloud.driver_id)
      rescue
        raise
        return
      end
      debug "[x] created - EC2 RouteTable for #{subnet.driver_id}"

      debug "assigning - EC2 Route Table #{ec2route_table.id} to EC2 Subnet #{subnet.driver_id}"
      begin
        AWS::EC2.new.subnets[subnet.driver_id].route_table = ec2route_table
      rescue
        raise
        return
      end
      debug "[x] assigned - EC2 Route Table #{ec2route_table.id} to EC2 Subnet #{subnet.driver_id}"

      if subnet.internet_accessible
        debug "creating - Internet Accessible RouteTable for EC2 Subnet #{subnet.driver_id}"
        begin
          ec2route_table.create_route("0.0.0.0/0", { internet_gateway: ec2cloud.internet_gateway} )
        rescue
          raise
          return
        end
        debug "[x] created - Internet Accessible Route for EC2 Subnet #{subnet.driver_id}"
      else
        debug "creating - Route for EC2 Subnet #{subnet.driver_id} to NAT"
        begin
          puts "\nNAT:#{subnet.cloud.scenario.get_instances.select{|i| i.internet_accessible}.first.driver_id}"
          ec2route_table.create_route("0.0.0.0/0", { instance: subnet.cloud.scenario.get_instances.select{|i| i.internet_accessible}.first.driver_id } )
        rescue
          raise
          return
        end
        debug "[x] created - Route for EC2 Subnet #{subnet.driver_id}"
      end
    end

    debug "creating - Firewall rules"
    begin
      # Hardcoded firewall rules - TODO
      ec2cloud.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
      ec2cloud.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
      ec2cloud.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
      ec2cloud.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
      # TODO -- SECURITY -- delayed job in 20 min disable firewall.
      ec2cloud.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
    rescue => e
      raise
      return
    end
    debug "[x] created - Firewall rules"

    debug "[x] finished booting Scenario #{self.id} #{self.name}"
  end

  def aws_scenario_boot_new
    begin
      debug "#########################################################\n# Booting\n#########################################################"
      aws_scenario_boot_private_new
    rescue => e
      aws_boot_error(self, e)
      return
    end
    debug ""
    self.set_booted
    PrivatePub.publish_to "/scenarios/#{self.id}", scenario_status: "booted"
  end

  #############################################################
  # Unboot 

  def aws_unboot_error(scenario, error)
    
    if error = AWS::EC2::Errors::Unavailable
      if scenario.boot_tries < 1
        debug "!!! AWS Service down. Will retry unboot in 10 seconds !!!"
        sleep 10
        scenario.boot_tries += 1
        scenario.aws_scenario_unboot_new
        return
      end
    end

    scenario.boot_tries = 0
    scenario.status = "unboot_failed"
    scenario.save

    PrivatePub.publish_to "/scenarios/#{scenario.id}", scenario_status: "unboot_failed"

    debug '\n---- Boot ERROR ---' + error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
    time = Time.new
    File.open("#{Rails.root}/log/boot.#{scenario.id}-#{scenario.name}.log", 'a') do |f|
      f.puts "\n"
      f.puts error.class.to_s + ' - ' + error.message.to_s + error.backtrace.join("\n")
      f.puts "\n"
    end
  end

  def aws_instances_stopping?(instances)
    if instances.select { |i| i.status == "stopped" or i.status == "stopping"}.size
      return true
    end
    return false
  end

  def aws_unboot_internet_gateway_new(internet_gateway, cloud)
    debug "  deleting InternetGateway #{internet_gateway.internet_gateway_id}"
    begin
      internet_gateway.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # raise
      # return
    rescue
      raise
      return
    end
    debug "  deleted InternetGateway"
  end

  def aws_unboot_route_table_new(route_table, cloud)
    debug "  deleting - RouteTable #{route_table.route_table_id}"
    begin
      route_table.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
      # return
    rescue
      raise
      return
    end
    debug "  [x] deleted - RouteTable"
  end
  
  def aws_unboot_security_group_new(security_group, cloud)
    debug "  deleting SecurityGroup #{security_group.security_group_id}"
    begin
      security_group.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
    rescue
      raise
      return
    end
    debug "  deleted SecurityGroup"
  end

  def aws_unboot_acl_new(acl, cloud)
    debug "  deleting ACL #{acl.id}"
    begin
      acl.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
      # return
    rescue
      raise
      return
    end
    debug "  deleted ACL"
  end

  def aws_unboot_instance_new(instance)
    debug "   unbooting - Instance #{instance.name}"

    # get EC2 instance
    debug "    getting - EC2 Instance #{instance.driver_id}"
    begin
      ec2instance = AWS::EC2.new.instances[instance.driver_id]
    rescue
      raise
      return
    end
    debug "    [x] got - EC2 Instance #{instance.driver_id}"

    # Mark devices deleteOnTermination
    debug "    setting - EC2 Instance #{instance.driver_id} volumes deleteOnTermination"
    begin
      ec2instance.block_devices.each do |device|
        AWS::EC2.new.client.modify_instance_attribute(
          instance_id: ec2instance.id,
          attribute: "blockDeviceMapping",
          block_device_mappings: [device_name: "#{device[:device_name]}", ebs:{ delete_on_termination: true}]
         )
      end
    rescue
      raise
      return
    end
    debug "    [x] set - EC2 Instance #{instance.driver_id} volumes deleteOnTermination"

    # disassociate and delete EIP's
    debug "    deleting any - EC2 Instance EIP's"
    begin
      if ec2eip = ec2instance.elastic_ip 
        ec2instance.disassociate_elastic_ip
        ec2eip.delete
      end
    rescue
      raise
      return
    end
    debug "    [x] deleted any - EC2 Instance EIP's"

    # delete EC2 Instance
    debug "    deleting - EC2 Instance #{instance.driver_id}"
    begin
      ec2instance.delete
    rescue
      raise
      return
    end
    # debug "stopping - EC2 Instance #{instance.driver_id}"
    instance.set_stopping
    instance.save

    # wait for instance to terminate
    begin
      cnt = 0
      until ec2instance.status_code == 48
        debug "    waiting #{(2**cnt).to_s} seconds for- EC2 Instance #{instance.driver_id} to terminate"
        sleep 2**cnt
        cnt += 1
        if cnt > 8
          raise "    EC2 Instance Terminate Wait Timeout"
          aws_unboot_error(subnet.cloud.scenario, $!)
          return
        end
      end
    rescue
      raise
      return
    end
    debug "    [x] EC2 Instance #{instance.driver_id} is now terminated"

    instance.driver_id = nil
    instance.set_stopped
    instance.add_progress -1
    instance.save
    debug "    [x] unbooted - Instance #{instance.name}"
  end

  def aws_unboot_subnet_new(subnet)
    debug "  unbooting - Subnet #{subnet.id}"

    subnet.instances.select{ |i| i.driver_id}.each do |instance|
      aws_unboot_instance_new(instance)
    end

    # debug "unbooting - Subnet #{subnet.id}"

    debug "   unbooting - EC2 Subnet #{subnet.driver_id}"
    begin
      ec2subnet = AWS::EC2.new.subnets[subnet.driver_id].delete
    rescue AWS::EC2::Errors::DependencyViolation => e
      if aws_instances_stopping?(subnet.instances)
        retry
      else
        raise
        return
      end
    rescue
      raise
      return
    end
    debug "    [x] unbooted - EC2 Subnet #{subnet.driver_id}"

    subnet.set_stopped
    subnet.driver_id = nil
    subnet.add_progress -1
    subnet.save
  end

  def aws_scenario_unboot_cloud_new(cloud)
    debug "  unbooting - Cloud #{cloud.id}"
    # get VPC from AWS

    cloud.subnets.select{ |s| s.driver_id}.each do |subnet|
      begin
        aws_unboot_subnet_new(subnet)
      rescue
        raise
        return
      end
    end

    debug "   getting - EC2 Cloud #{cloud.driver_id}"
    begin 
      vpc = AWS::EC2.new.vpcs[cloud.driver_id]
    rescue
      raise
      return
    end
    debug "   [x] got - EC2 Cloud #{cloud.driver_id}"

    if vpc.internet_gateway and vpc.internet_gateway.exists?
      igw = vpc.internet_gateway

      debug "   detaching - InternetGateway #{vpc.internet_gateway.internet_gateway_id}"
      begin
        vpc.internet_gateway.detach(vpc)
      rescue
        raise
        return
      end
      debug "   [x] detached - EC2 InternetGateway #{igw.internet_gateway_id}"
      
      debug "   deleting - EC2 InternetGateway #{igw.internet_gateway_id}"
      begin
        igw.delete
      rescue
        raise
        return
      end
      debug "   [x] deleted - InternetGateway"

    end

    vpc.network_acls.select{ |acl| !acl.default}.each do |acl|
      aws_unboot_acl_new(acl, cloud)
    end

    vpc.security_groups.select{ |sg| !sg.name == "default"}.each do |security_group|
      aws_unboot_security_group_new(security_group, cloud)
    end

    vpc.route_tables.select{ |rt| !rt.main?}.each do |route_table|
      aws_unboot_route_table_new(route_table, cloud)
    end

    begin
      network_acls = vpc.network_acls
    rescue
      raise
      return
    end

    debug "   unbooting - VPC #{cloud.driver_id}"
    begin
      vpc.delete
    rescue AWS::EC2::Errors::DependencyViolation => e
      if aws_instances_stopping?(cloud.scenario.get_instances)
        retry
      else
        raise
        return
      end
    rescue
      raise
      return
    end
    debug "   [x] unbooted - Cloud #{cloud.driver_id}"

    cloud.driver_id = nil
    cloud.set_stopped
    cloud.add_progress -1
    cloud.save
  end

  def aws_scenario_unboot_new_private
    debug "unbooting - #{self.name}"
    self.clouds.select{|c| c.driver_id}.each do |cloud|
      begin
        aws_scenario_unboot_cloud_new(cloud)
      rescue
        raise
        return
      end
    end
    self.set_stopped
    self.save
    debug "[x] FINISHED unbooting - #{self.name}"
    PrivatePub.publish_to "/scenarios/#{self.id}", scenario_status: "stopped"
  end

  def aws_scenario_unboot_new 
    debug "#########################################################\n# Unbooting"
    begin
      aws_scenario_unboot_new_private
    rescue => e
      aws_unboot_error(self, e)
      return
    end
  end

  ##############################################################
  # SCORING

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
    self.update(scoring_page: bucket.objects[self.uuid + "-scoring-" + self.name].url_for(:read, expires: 10.hours).to_s)
  end

end