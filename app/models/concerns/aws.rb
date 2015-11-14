# This file contains the implementation of the AWS API calls. They are implemented
# as hooks, called dynamically by the {Provider} concern when {Scenario}, {Cloud}, {Subnet}, and {Instance} are booted.
# @see Provider#boot
require 'active_support'
module Aws
  extend ActiveSupport::Concern

  # #############################################################
  # #  Boot and Unboot

  def aws_boot_scenario(options = {})

    # Do nothing if already booted
    if self.booted?
      return true
    end

    # Do initial scoring setup
    begin
      self.aws_scenario_initialize_scoring
    rescue => e
      self.boot_error(e)
      return false
    end

    # Boot each Cloud
    if options[:dependents]
      self.clouds.each do |cloud|
        begin
          if not cloud.boot(options)
            return false
          end
        rescue => e
          self.boot_error(e)
          return false
        end
      end

      # Wait for clouds to finish booting
      begin
        cnt = 0
        until not self.clouds_booting?
          debug "waiting - for clouds to finish booting"
          if cnt > 600
            raise "ERROR - scenario timed out waiting for clouds to finish"
          end
          cnt += 1
          sleep 2
          self.reload
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      # Check if any clouds have failed to boot
      begin
        if self.clouds_boot_failed?
          raise "ERROR - one or more clouds have failed to boot"
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      # Wait for subnets to finish booting
      begin
        cnt = 0
        until not self.subnets_booting?
          debug "waiting - for subnets to finish booting"
          if cnt > 600
            raise "ERROR - scenario timed out waiting for subnets to finish"
          end
          cnt += 1
          sleep 2
          self.reload
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      # Wait for all instances to finish booting
      begin
        debug "waiting - for instances to finish booting"
        cnt = 0
        until self.instances.select{ |i| i.booted? }.size == self.instances.size
          sleep 2
          cnt += 1
          if cnt > 600
            raise "ERROR - scenario timed out waiting for instances to finish booting"
          end
          self.reload
        end
      rescue => e
        self.boot_error(e)
        return false
      end

    end

    self.set_booted
    self.debug_booting_finished
    true
  end

  def aws_unboot_scenario(options = {})
    
    if options[:dependents]
      self.clouds.each do |cloud|
        begin
          if not cloud.unboot(options)
            return false
          end
        rescue => e
          self.unboot_error(e)
          return false
        end
      end

      # Wait for clouds to unboot
      begin
        debug "wating - for clouds to unboot"
        cnt = 0
        until not self.clouds_unbooting?
          sleep 2
          cnt += 1
          if cnt > 600
            raise "ERROR - unboot timed out waiting for clouds to finish unbooting"
          end
          self.reload
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      # Check clouds for unboot errors
      begin
        if self.clouds_unboot_failed?
          raise "ERROR - one or more clouds have failed to unboot"
        end
      rescue => e
        self.unboot_error(e)
        return false
      end

    end

    # Delete scoring pages
    begin
      aws_scenario_scoring_purge
    rescue => e
      self.unboot_error(e)
      return false
    end

    self.set_stopped
    self.debug_unbooting_finished
    true
  end

  def aws_pause_scenario
    self.instances.each do |instance|
      instance.pause
    end
    self.set_paused
  end

  def aws_start_scenario
    self.instances.each do |instance|
      instance.start
    end
    self.set_booted
  end

  # Boots {Cloud}, and all of its {Subnet Subnets}.
  # Creates a AWS::EC2::VPC object with Subnet's cidr_block
  # @return [nil]
  def aws_boot_cloud(options = {})

    # Initialize scoring if it is not already done
    begin
      self.scenario.aws_scenario_initialize_scoring
    rescue => e
      self.boot_error(e)
      return false
    end

    # Boot if not booted
    if self.driver_id == nil

      # Create VPC, assign driver_id, and create Internet Gateway
      begin
        debug "creating - VPC"
        ec2vpc = AWS::EC2.new.vpcs.create(self.cidr_block)
      rescue => e
        self.boot_error(e)
        return false
      end

      # Assign driver_id
      debug "assigning - VPC driver_id"
      begin
        self.update_attribute(:driver_id, ec2vpc.id)
      rescue => e
        self.boot_error(e)
        return false
      end

      # Create Internet Gateway
      debug "creating - Internet Gateway"
      begin
        ec2vpc.internet_gateway = AWS::EC2.new.internet_gateways.create
      rescue => e
        self.boot_error(e)
        return false
      end

      # Wait for VPC to become available
      begin
        cnt = 0
        debug "waiting - for VPC #{self.driver_id} to become available"
        until ec2vpc.state == :available
          sleep 2
          cnt += 1
          if cnt == 30
            raise "timeout - waiting for VPC to become available"
            return false
          end
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      # Create routing rules
      begin
        debug "creating - routing rules"
        # Hardcoded firewall rules - TODO
        ec2vpc.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
        ec2vpc.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
        ec2vpc.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
        ec2vpc.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
        # TODO -- SECURITY -- delayed job in 20 min disable firewall.
        ec2vpc.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
      rescue => e
        self.boot_error(e)
        return false
      end

      tries = 0
      begin
        debug "creating - tags"
        AWS::EC2.new.tags.create(ec2vpc, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2vpc, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2vpc, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2vpc, "scenario", value: self.scenario.id)

        AWS::EC2.new.tags.create(ec2vpc.internet_gateway, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2vpc.internet_gateway, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2vpc.internet_gateway, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2vpc.internet_gateway, "scenario", value: self.scenario.id)

        AWS::EC2.new.tags.create(ec2vpc.security_groups.first, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2vpc.security_groups.first, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2vpc.security_groups.first, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2vpc.security_groups.first, "scenario", value: self.scenario.id)

        AWS::EC2.new.tags.create(ec2vpc.network_acls.first, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2vpc.network_acls.first, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2vpc.network_acls.first, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2vpc.network_acls.first, "scenario", value: self.scenario.id)

        AWS::EC2.new.tags.create(ec2vpc.route_tables.first, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2vpc.route_tables.first, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2vpc.route_tables.first, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2vpc.route_tables.first, "scenario", value: self.scenario.id)

      rescue AWS::EC2::Errors::InvalidVpcID::NotFound => e
        debug "vpc id not found trying again"
        tries += 1
        if tries < 20
          sleep 1
          retry
        else
          self.boot_error(e)
        end
      rescue => e
        self.boot_error(e)
        return false
      end

      self.set_booted
      self.debug_booting_finished
    else
      self.set_stopped
      return false
    end

    # boot dependent Subnets
    if options[:dependents]
      self.subnets.each do |subnet|
        begin
          if not subnet.boot(options)
            return false
          end
        rescue => e
          self.boot_error(e)
          return false
        end
      end
    end
    true
  end

  def aws_unboot_cloud(options = {})

    # Unboot dependents
    if options[:dependents]
      self.subnets.each do |subnet|
        begin
          if not subnet.unboot(options)
            return false
          end
        rescue => e
          self.unboot_error(e)
          return false
        end
      end

      # Wait for subnets to unboot
      begin
        debug "wating - for subnets to unboot"
        cnt = 0
        until not self.subnets_unbooting?
          sleep 2
          cnt += 1
          if cnt > 600
            raise "ERROR - unboot timed out waiting for subnets to finish unbooting"
          end
          self.reload
        end
      rescue => e
        self.unboot_error(e)
        return false
      end

      # Check subnets for unboot errors
      begin
        if self.subnets_unboot_failed?
          raise "subnets unboot failed"
        end
      rescue => e
        self.unboot_error(e)
        return false
      end

    end

    # Get VPC object
    begin
      debug "getting - EC2 Cloud #{self.driver_id}"
      vpc = AWS::EC2.new.vpcs[self.driver_id]
    rescue => e
      self.unboot_error(e)
      return false
    end

    # Detach and delete any InternetGateways 
    if vpc.internet_gateway and vpc.internet_gateway.exists?
      igw = vpc.internet_gateway

      debug "detaching - InternetGateway #{vpc.internet_gateway.internet_gateway_id}"
      begin
        vpc.internet_gateway.detach(vpc)
      rescue => e
        self.unboot_error(e)
        return false
      end

      debug "deleting - EC2 InternetGateway #{igw.internet_gateway_id}"
      begin
        igw.delete
      rescue => e
        self.unboot_error(e)
        return false
      end

    end

    # Delete ACL's
    vpc.network_acls.select{ |acl| !acl.default}.each do |acl|
      aws_unboot_acl_new(acl, self)
    end

    # Delete Security Groups
    vpc.security_groups.select{ |sg| !sg.name == "default"}.each do |security_group|
      aws_unboot_security_group_new(security_group, self)
    end

    # Delete Routing Tables
    vpc.route_tables.select{ |rt| !rt.main?}.each do |route_table|
      aws_unboot_route_table_new(route_table, self)
    end

    # Delete the VPC
    tries = 0
    begin
      debug "unbooting - VPC #{self.driver_id}"
      vpc.delete
    rescue AWS::EC2::Errors::InvalidVpcID::NotFound => e
      if tries < 120
        sleep 2
        tries += 1
      else
        self.unboot_error(e)
        return false
      end
    rescue AWS::EC2::Errors::DependencyViolation => e
      if tries < 120
        if aws_instances_stopping?(self.scenario.instances)
          sleep 2
          tries += 1
          retry
        else
          self.unboot_error(e)
          return false
        end
      else 
        self.unboot_error(e)
        return false
      end
    rescue => e
      self.unboot_error(e)
      return false
    end

    self.update_attribute(:driver_id, nil)
    self.set_stopped
    self.debug_unbooting_finished
    true
  end

  # Boots {Subnet}, and all of its {Instance Instances}.
  # Creates a AWS::EC2::Subnet object, taking Subnet's `cidr_block` and the `VPC ID` of the {Cloud} the {Subnet} resides in.
  # @return [nil]
  def aws_boot_subnet(options = {})

    if self.driver_id == nil

      # create Subnet
      debug "creating - EC2 Subnet"
      begin
        ec2subnet = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id)
      rescue => e
        self.boot_error(e)
        return false
      end

      # set driver_id
      debug "assigning - Subnet #{self.id} driver_id"
      begin
        self.update_attribute(:driver_id, ec2subnet.id)
      rescue => e
        self.boot_error(e)
        return false
      end

      # wait till Subnet is available
      begin
        cnt = 0
        until ec2subnet.state == :available
          debug "waiting for - EC2 Subnet #{self.driver_id} to become available"
          sleep 2**cnt
          cnt += 1
          if cnt == 9
            raise "Timedout waiting for VPC to become available"
            self.boot_error($!)
            return false
          end
        end
      rescue AWS::EC2::Errors::InvalidSubnetID::NotFound
        debug "invalid subnet id - trying again"
        retry
      rescue => e
        self.boot_error(e)
        return false
      end

      # do routing 
      debug "creating - EC2 RouteTable for #{self.driver_id}"
      begin
        ec2route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: self.cloud.driver_id)
      rescue => e
        self.boot_error(e)
        return false
      end

      debug "assigning - EC2 Route Table #{ec2route_table.id} to EC2 Subnet #{self.driver_id}"
      begin
        ec2subnet.route_table = ec2route_table
      rescue => e
        self.boot_error(e)
        return false
      end

      debug "getting - EC2 Cloud #{self.cloud.driver_id}"
      begin
        ec2cloud = AWS::EC2.new.vpcs[self.cloud.driver_id]
      rescue => e
        self.boot_error(e)
        return false
      end

      if self.internet_accessible
        debug "creating - Internet Accessible RouteTable for EC2 Subnet #{self.driver_id}"
        begin
          ec2route_table.create_route("0.0.0.0/0", { internet_gateway: ec2cloud.internet_gateway} )
        rescue => e
          self.boot_error(e)
          return false
        end
      end

      debug "creating tags"
      begin
        AWS::EC2.new.tags.create(ec2subnet, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2subnet, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2subnet, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2subnet, "scenario", value: self.scenario.id)

        AWS::EC2.new.tags.create(ec2route_table, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
        AWS::EC2.new.tags.create(ec2route_table, "host", value: Settings.host)
        AWS::EC2.new.tags.create(ec2route_table, "instructor", value: self.scenario.user.name)
        AWS::EC2.new.tags.create(ec2route_table, "scenario", value: self.scenario.id)
      rescue => e
        self.boot_error(e)
        return false
      end

      debug "booted - Subnet #{self.name}"
      self.set_booted
      self.debug_booting_finished
    end

    if options[:dependents]
      self.instances.select{ |i| !i.driver_id}.each do |instance|
        begin
          if not instance.boot(options)
            return false
          end
        rescue => e
          self.boot_error(e)
          return false
        end
      end
    end
    true
  end

  def aws_unboot_subnet(options = {})

    debug "unbooting - Subnet #{self.id}"

    if options[:dependents]
      self.instances.each do |instance|
        if instance.driver_id
          if options[:run_asynchronously]
            # instance.set_unbooting
            instance.delay(queue: 'instance').unboot
          else
            if not instance.unboot
              return false
            end
          end
        else
          instance.set_stopped
        end
      end

      debug "wating - for instances to unboot"
      # need to do a timeout for this
      until not self.instances_unbooting?
        sleep 2
        self.reload
      end

      begin
        if self.instances_unboot_failed?
          raise "subnets instances failed to boot"
        end
      rescue => e
        self.unboot_error(e)
        return false
      end

    else

      # if not unbooting dependents make sure no instances are booted
      if self.instances_booted?
        begin
          raise "Instances not unbooted"
        rescue => e
          self.unboot_error(e)
          return false
        end
      end

    end

    debug "disassociating - subnets route table"
    begin
      AWS::EC2.new.subnets[self.driver_id].route_table_association.delete
      # debug "here"
      # assoc.delete unless assoc.main?
      # debug "after"
    rescue => e
      self.unboot_error(e)
      return false
    end

    # debug "deleting - subnets route table"
    # begin
    #   AWS::EC2.new.subnets[self.driver_id].route_table.delete
    # rescue => e
    #   self.unboot_error(e)
    #   return false
    # end

    debug "unbooting - EC2 Subnet #{self.driver_id}"
    begin
      ec2subnet = AWS::EC2.new.subnets[self.driver_id].delete
    rescue AWS::EC2::Errors::DependencyViolation => e
      if aws_instances_stopping?(self.instances)
      # if aws_instances_stopping?(self.instances)
        sleep 2
        retry
      else
        self.unboot_error(e)
        return false
      end
    rescue => e
      self.unboot_error(e)
      return false
    end

    self.update_attribute(:driver_id, nil)
    self.debug_unbooting_finished
    self.set_stopped
    true
  end

  # # Boots {Instance}, generating required cookbooks and startup scripts.
  # # This method largely defers to {InstanceTemplate} in order to generate shell scripts and
  # # chef scripts to configure each instance.
  # # Additionally, it uploads and stores the cookbook_url, which is generated by calling {#aws_instance_upload_cookbook}
  # # @return [nil]
  def aws_boot_instance(options = {})

    # scoring
    if self.roles.select { |r| r.recipes.find_by_name('scoring') }.size > 0
      begin
        self.aws_instance_initialize_scoring
        self.reload
        self.scenario.update_attribute(:scoring_pages_content, self.scenario.read_attribute(:scoring_pages_content) + self.scoring_page + "\n")
        self.scenario.aws_scenario_write_to_scoring_pages
      rescue => e
        self.boot_error(e)
        return false
      end
    end

    # create intitiation scripts
    debug "creating - Instance init"
    begin
      debug "generating - instance cookbook"
      self.aws_instance_create_com_page
      self.aws_instance_create_bash_history_page
      self.aws_instance_create_exit_status_page
      self.aws_instance_create_script_log_page

      debug "uploading - instance cookbook"
      self.aws_instance_upload_cookbook(self.generate_cookbook)
      
      debug "generating - instance chef script"
      cloud_init = self.generate_init
    rescue => e
      self.boot_error(e)
      return false
    end

    # get ami based on OS
    if self.os == 'nat'
      aws_instance_ami = Settings.ami_nat
    elsif self.os == 'ubuntu'
      aws_instance_ami = Settings.ami_ubuntu
    end

    # create EC2 Instance
    debug "creating - EC2 Instance"
    instance_type_num = 0
    tries = 0
    # instance_types = ["t1.micro", "m3.micro", "t1.small", "m3.small"]
    # instance_types = ["t1.micro"]
    instance_types = ["t2.micro"]
    begin
      debug "tyring Instance Type #{instance_types[instance_type_num]}"
      ec2instance = AWS::EC2::InstanceCollection.new.create(
        image_id: aws_instance_ami, # ami_id string of os image
        private_ip_address: self.ip_address, # ip string
        key_name: Settings.ec2_key, # keypair string
        user_data: cloud_init, # startup data
        instance_type: instance_types[instance_type_num],
        subnet: self.subnet.driver_id
      )
      debug "updating instance attribute"
      self.update_attribute(:driver_id, ec2instance.id)
      debug "updated instance attribute - #{self.driver_id}"
    rescue NoMethodError => e
      debug "- NoMethodError"
      self.boot_error(e)
      return false
    rescue AWS::EC2::Errors::InvalidParameterCombination => e
      debug "- InvalidParameterCombination"
      # wrong instance type
      self.boot_error(e)
      return false
    rescue AWS::EC2::Errors::InvalidSubnetID::NotFound => e
      debug "- InvalidSubnet"
      tries += 1
      if tries > 3
        self.boot_error(e)
        return false
      end
      sleep 2
      retry
    rescue AWS::EC2::Errors::InsufficientInstanceCapacity => e
      debug "- InsufficientInstanceCapacity"
      if instance_type_num <= instance_types.size
        instance_type_num += 1
        retry
      else
        self.boot_error(e)
        return false
      end
    rescue AWS::EC2::Errors::Unsupported => e
      debug "- Unsupported"
      tries += 1
      if tries > 3
        self.boot_error(e)
        return false
      end
      sleep 10
      retry
    rescue => e
      debug "- Other Error"
      self.boot_error(e)
      return false
    end

    # wait for Instance to become available
    debug "waiting for - EC2 Instance #{self.driver_id} to become available"
    tries = 0
    begin
      cnt = 0
      until ec2instance.status == :running
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          self.boot_error($!)
          return false
        end
      end
    rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
      if tries > 5
        self.boot_error(e)
        return false
      end
      tries += 1
      sleep 3
      retry
    rescue => e
      self.boot_error(e)
      return false
    end

    # for Internet Accessible instances
    if self.internet_accessible
      # create Elastip IP
      debug "creating - EC2 Elastic IP"
      begin
        ec2eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      rescue => e
        self.boot_error(e)
        return false
      end

      # wait for EIP to become available
      cnt = 0
      until ec2eip.exists?
        debug "waiting for - EC2 Elastic IP #{self.driver_id} to become available"
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to become available"
          self.boot_error($!)
          return false
        end
      end

      # associate instance with EIP
      debug "associating - EC2 Elastip IP with EC2 Instance #{ec2instance.id}"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
      rescue => e
        self.boot_error(e)
        return false
      end

      # accept packets coming in
      debug "accepting - EC2 Instance NIC packets, disabe source dest checks"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
        ec2instance.network_interfaces.first.source_dest_check = false
      rescue => e
        self.boot_error(e)
        return false
      end
    end

    # create route table to the nat if instances subnet is not internet accessible
    if not self.subnet.internet_accessible
      debug "creating - Route for EC2 Subnet #{self.driver_id} to NAT"
      begin

        nat = self.subnet.cloud.scenario.instances.select{|i| i.internet_accessible}.first
        if nat
          debug "waiting - for nat to boot to make route"
          until nat.booted?
            sleep 1
            nat.reload
          end
          AWS::EC2.new.subnets[self.subnet.driver_id].route_table.create_route("0.0.0.0/0", { instance: nat.driver_id } )
        end

      rescue => e
        self.boot_error(e)
        return false
      end
    end
    
    # create tags
    debug "creating tag"
    begin
      AWS::EC2.new.tags.create(ec2instance, "Name", value: Settings.host + "-" + self.scenario.user.name + '-' + self.scenario.name + '-' + self.scenario.id.to_s)
      AWS::EC2.new.tags.create(ec2instance, "host", value: Settings.host)
      AWS::EC2.new.tags.create(ec2instance, "instructor", value: self.scenario.user.name)
      AWS::EC2.new.tags.create(ec2instance, "scenario", value: self.scenario.id)
    rescue => e
      self.boot_error(e)
      return false
    end

    self.set_booted
    self.debug_booting_finished
    debug "[x] booted - Instance #{self.name}"
    true
  end

  def aws_unboot_instance(options = {})

    # check if instance exists

    debug "getting - EC2 Instance #{self.driver_id}"
    begin
      ec2instance = AWS::EC2.new.instances[self.driver_id]
    rescue => e
      self.unboot_error(e)
      return false
    end

    debug "setting - EC2 Instance #{self.driver_id} volumes deleteOnTermination"
    begin
      ec2instance.block_devices.each do |device|
        AWS::EC2.new.client.modify_instance_attribute(
          instance_id: ec2instance.id,
          attribute: "blockDeviceMapping",
          block_device_mappings: [device_name: "#{device[:device_name]}", ebs:{ delete_on_termination: true}]
         )
      end
    rescue => e
      self.unboot_error(e)
      return false
    end

    debug "deleting any - EC2 Instance EIP's"
    begin
      if ec2eip = ec2instance.elastic_ip
        ec2instance.disassociate_elastic_ip
        ec2eip.delete
      end
    rescue => e
      self.unboot_error(e)
      return false
    end

    debug "deleting - EC2 Instance #{self.driver_id}"
    begin
      ec2instance.delete
    rescue => e
      self.unboot_error(e)
      return false
    end

    debug "stopping - EC2 Instance #{self.driver_id}"

    # wait for instance to terminate
    begin
      cnt = 0
      until ec2instance.status_code == 48
        debug "waiting #{(2**cnt).to_s} seconds for - EC2 Instance #{self.driver_id} to terminate"
        sleep 2**cnt
        cnt += 1
        if cnt > 9
          raise "EC2 Instance Terminate Wait Timeout"
          self.unboot_error($!)
          return false
        end
      end
    rescue => e
      self.unboot_error(e)
      return false
    end

    # remove s3 files
    debug "removing s3 files"
    begin
      self.aws_instance_delete_cookbook
      self.aws_instance_delete_com_page
      self.aws_instance_delete_scoring_page
    rescue => e
      self.unboot_error(e)
      return false
    end

    self.update_attribute(:driver_id, nil)
    self.set_stopped
    self.debug_unbooting_finished
    true
  end

  def aws_pause_instance
    if (not self.driver_id) or (not self.booted?)
      return false
    end

    self.set_pausing
    begin
      i = AWS::EC2.new.instances[self.driver_id]
      return if not i.exists?
      i.stop

      cnt = 0
      until i.status == :stopped
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to stop"
          self.boot_error($!)
          return
        end
      end
    rescue => e
      self.boot_error(e)
      return false
    end

    self.set_paused
    true
  end

  def aws_start_instance
    if (not self.driver_id) or (not self.paused?)
      return false
    end

    self.set_starting
    begin
      i = AWS::EC2.new.instances[self.driver_id]
      return if not i.exists?
      i.start

      cnt = 0
      until i.status == :running
        sleep 2**cnt
        cnt += 1
        if cnt == 20
          raise "Timeout Waiting for VPC to start"
          self.boot_error($!)
          return false
        end
      end
    rescue => e
      self.boot_error(e)
      return false
    end

    self.set_booted
    true
  end

  ## Unboot Helpers
  def aws_unboot_internet_gateway_new(internet_gateway, cloud)
    #debug "  deleting InternetGateway #{internet_gateway.internet_gateway_id}"
    begin
      internet_gateway.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # raise
      # return
    rescue
      raise
      return
    end
    #debug "  deleted InternetGateway"
  end

  def aws_unboot_route_table_new(route_table, cloud)
    #debug "  deleting - RouteTable #{route_table.route_table_id}"
    begin
      route_table.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
      # return
    rescue
      raise
      return
    end
    #debug "  [x] deleted - RouteTable"
  end

  def aws_unboot_security_group_new(security_group, cloud)
    #debug "  deleting SecurityGroup #{security_group.security_group_id}"
    begin
      security_group.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
    rescue
      raise
      return
    end
    #debug "  deleted SecurityGroup"
  end

  def aws_unboot_acl_new(acl, cloud)
    #debug "  deleting ACL #{acl.id}"
    begin
      acl.delete
    # rescue AWS::EC2::Errors::DependencyViolation => e
      # aws_unboot_error(cloud.scenario, e)
      # return
    rescue
      raise
      return
    end
    #debug "  deleted ACL"
  end

  #############################################################
  # Helpers

  def aws_instances_stopping?(instances)
    return instances.select { |i| i.status == "stopped" or i.status == "stopping"}.any?
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
  # def aws_cloud_check_status
  #   if self.aws_cloud_driver_object.state == :available
  #     self.update(status: "booted")
  #   end
  # end

  # @return [Boolean] Whether or not the {Subnet} is internet_accessible
  def aws_subnet_nat?
    @internet_accessible
  end

  # @return [Boolean] Whether or not the {Subnet} is booted
  # def aws_subnet_check_status
  #   if self.aws_subnet_driver_object.state == :available
  #     self.update(status: "booted")
  #   end
  # end

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
    self.instances.each do |instance|
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

    cnt = 0
    begin 
      return @public_ip ||= self.aws_instance_driver_object.public_ip_address
    rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
      if cnt < 60
        sleep 2
        cnt += 1
        retry
      else
        return false
      end
    end

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

  ##############################################################
  # S3 page (SCORING, COOKBOOKS, COM)

  # This uploads our chef cookbook into S3, and gets us a url. This is given to the shell script
  # which sets a cron job to download and run the chef recipe.
  # @param cookbook_text The text to upload to S3
  # @return [String] A URL generated from S3 pointing to our text

  def aws_S3_create_page(name, permissions, content)
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[name].write(content) if content
      return bucket.objects[name].url_for(permissions, expires: 10.days, :content_type => 'text/plain').to_s
    rescue
      raise
      return
    end
  end

  def aws_S3_delete_page(name)
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      bucket.objects[name].delete
    rescue
      raise
      return
    end
  end

  def aws_S3_name_prefix
    return "#{Settings.host}_#{self.scenario.user.name}_#{self.scenario.name}_#{self.scenario.id.to_s}"
  end

  # Cookbooks

  def aws_instance_cookbook_name
    return "#{aws_S3_name_prefix}_cookbook_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_upload_cookbook(cookbook_text)
    debug "creating s3 cookbook"
    begin 
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[self.aws_instance_cookbook_name].write(cookbook_text)
      self.update_attribute(:cookbook_url, bucket.objects[self.aws_instance_cookbook_name].url_for(:read, expires: 10.days).to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_delete_cookbook
    debug "deleting s3 cookbook"
    begin
      aws_S3_delete_page(self.aws_instance_cookbook_name)
      self.update_attribute(:cookbook_url, nil)
    rescue
      raise
      return
    end
  end

  # Communication

  def aws_instance_com_page_name
    return "#{aws_S3_name_prefix}_compage_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_create_com_page
    debug "creating s3 com page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[aws_instance_com_page_name].write("waiting")
      self.update_attribute(:com_page, bucket.objects[aws_instance_com_page_name].url_for(:write, expires: 10.days, :content_type => 'text/plain', endpoint: Settings.endpoint)).to_s
    rescue
      raise
      return
    end
  end

  def aws_instance_delete_com_page
    debug "deleting s3 com page"
    begin
      aws_S3_delete_page(self.aws_instance_com_page_name)
      self.update_attribute(:com_page, nil)
    rescue
      raise
      return
    end
  end

  # Bash History

  def aws_instance_bash_history_page_name
    return "#{aws_S3_name_prefix}_bash_history_page_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_create_bash_history_page
    debug "creating s3 bash history page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      self.update_attribute(:bash_history_page, bucket.objects[aws_instance_bash_history_page_name].url_for(:write, expires: 10.days, :content_type => 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_exit_status_page_name
    return "#{aws_S3_name_prefix}_exit_status_page_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_create_exit_status_page
    debug "creating s3 exit status page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      self.update_attribute(:exit_status_page, bucket.objects[aws_instance_exit_status_page_name].url_for(:write, expires: 10.days, :content_type => 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_script_log_page_name
    return "#{aws_S3_name_prefix}_script_log_page_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_create_script_log_page
    debug "creating s3 script log page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      self.update_attribute(:script_log_page, bucket.objects[aws_instance_script_log_page_name].url_for(:write, expires: 10.days, :content_type => 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_delete_bash_history_page
    debug "deleting s3 bash history page"
    begin
      aws_S3_delete_page(self.aws_instance_bash_history_page_name)
      # self.update_attribute(:bash_history_page, nil)
    rescue
      raise
      return
    end
  end

  def aws_instance_delete_exit_status_page
    debug "deleting s3 exit status page"
    begin
      aws_S3_delete_page(self.aws_instance_exit_status_page_name)
      # self.update_attribute(:exit_status_page, nil)
    rescue
      raise
      return
    end
  end

   def aws_instance_delete_script_log_page
    debug "deleting s3 script log page"
    begin
      aws_S3_delete_page(self.aws_instance_script_log_page_name)
      # self.update_attribute(:script_log_page, nil)
    rescue
      raise
      return
    end
  end
  #######################################################################
  # Scoring

  # Scenario Scoring

  def aws_scenario_initialize_scoring
    begin
      if not self.scoring_pages
        debug "creating scoring pages s3 file"
        self.aws_scenario_create_scoring_pages
      end
      if not self.answers_url
        debug "creating answers url s3 file"
        self.aws_scenario_create_answers_url
      end
    rescue
      raise
      return
    end
  end

  def aws_scenario_scoring_pages_name
    return "#{aws_S3_name_prefix}_scenario_scoring_pages_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_scenario_create_scoring_pages
    debug "creating s3 scoring page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      self.update_attribute(:scoring_pages, bucket.objects[aws_scenario_scoring_pages_name].url_for(:read, expires: 10.days).to_s)
    rescue
      raise
      return
    end
  end

  def aws_scenario_write_to_scoring_pages
    begin 
      AWS::S3.new.buckets[Settings.bucket_name].objects[aws_scenario_scoring_pages_name].write(self[:scoring_pages_content])
    rescue
      raise
      return
    end
  end

  def aws_scenario_delete_scoring_pages
    debug "deleting s3 scoring pages"
    begin 
      AWS::S3.new.buckets[Settings.bucket_name].objects[aws_scenario_scoring_pages_name].delete
      self.update_attribute(:scoring_pages, nil)
    rescue AWS::S3::Errors::PermanentRedirect 
      return true
    rescue AWS::S3::Errors::NoSuchBucket
      return true
    rescue
      raise
      return
    end
  end

  def aws_scenario_answers_url_name
    return "#{aws_S3_name_prefix}_scenario_answers_url_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_scenario_create_answers_url
    debug "creating s3 answers page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      object = bucket.objects[aws_scenario_answers_url_name]
      object.write(self.answers)
      self.update_attribute(:answers_url, object.url_for(:read, expires: 10.days).to_s)
    rescue
      raise
      return
    end
  end

  def aws_scenario_delete_answers_url
    debug "deleting s3 delete answers page"
    begin 
      AWS::S3.new.buckets[Settings.bucket_name].objects[aws_scenario_answers_url_name].delete
      self.update_attribute(:answers_url, nil)
    rescue AWS::S3::Errors::PermanentRedirect
      return true
    rescue AWS::S3::Errors::NoSuchBucket
      return true
    rescue
      raise
      return
    end
  end

  def aws_scenario_scoring_purge
    begin
      self.aws_scenario_delete_scoring_pages
      self.aws_scenario_delete_answers_url
    rescue
      raise
      return
    end
  end

  # Instance Scoring

  def aws_instance_initialize_scoring
    begin
      if not self.scoring_page
        self.aws_instance_create_scoring_page
      end
      if not self.scoring_url
        self.aws_instance_create_scoring_url
      end
    rescue
      raise
      return
    end
  end

  def aws_instance_scoring_page_name
    return "#{aws_S3_name_prefix}_instance_scoring_#{self.name}_#{self.id.to_s}_#{self.uuid}"
  end

  def aws_instance_create_scoring_url
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[aws_instance_scoring_page_name].write("# put your answers here")
      self.update_attribute(:scoring_url, bucket.objects[aws_instance_scoring_page_name].url_for(:write, expires: 10.days, :content_type => 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_create_scoring_page
    debug "creating s3 scoring page"
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      self.update_attribute(:scoring_page, bucket.objects[aws_instance_scoring_page_name].url_for(:read, expires: 10.days).to_s)
    rescue
      raise
      return
    end
  end

  def aws_instance_delete_scoring_page
    debug "deleting s3 scoring page"
    begin 
      AWS::S3.new.buckets[Settings.bucket_name].objects[aws_instance_scoring_page_name].delete
      self.update_attribute(:scoring_page, nil)
    rescue
      raise
      return
    end
  end

end
