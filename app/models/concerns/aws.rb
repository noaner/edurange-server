# This file contains the implementation of the AWS API calls. They are implemented
# as hooks, called dynamically by the {Provider} concern when {Scenario}, {Cloud}, {Subnet}, and {Instance} are booted.
# @see Provider#boot
require 'active_support'
module Aws
  extend ActiveSupport::Concern

  # #############################################################
  # #  Boot and Unboot

  def aws_boot_scenario(options = {})
    debug "booting Scenario #{self.name}"
    self.set_booting
    
    debug "------------------------------------------"
    debug "booting Scenario #{self.name}"

    # boot each Cloud
    if options[:boot_dependents]
      self.clouds.select{|c| !c.driver_id}.each do |cloud|
        begin
          if options[:run_asynchronously]
            cloud.delay(queue: 'clouds').boot(options)
          else
            cloud.boot(options)
          end
        rescue => e
          self.boot_error(e)
          return
        end
      end

      debug "scenario #{self.name} waiting for clouds"
      until not self.clouds_booting?
        sleep 2
        self.reload
      end

      begin
        if self.clouds_boot_failed?
          raise "clouds failed to boot"
        end
      rescue => e
        self.boot_error(e)
        return
      end

    end

    debug "[x] FINISHED unbooting - #{self.name}"
    self.set_booted
  end

  def aws_unboot_scenario(options = {})
    self.set_unbooting
    debug "unbooting - #{self.name}"

    if options[:unboot_dependents]
      self.clouds.each do |cloud|
        begin
          if cloud.driver_id
            if options[:run_asynchronously]
              cloud.set_unbooting
              cloud.delay(queue: 'clouds').unboot(options)
            else
              cloud.unboot(options)
            end
          else
            cloud.set_stopped
          end
        rescue => e
          self.unboot_error(e)
          return
        end
      end

      debug "wating - for clouds to unboot"
      until not self.clouds_unbooting?
        sleep 2
        self.reload
      end

      begin
        if self.clouds_unboot_failed?
          raise "clouds unboot failed"
        end
      rescue => e
        self.unboot_error(e)
      end

    else
      if self.clouds_booted?
        begin
          raise "Clouds not unbooted"
        rescue => e
          self.unboot_error(e)
          return
        end
      end
    end

    self.set_stopped
    self.clear_log
    debug "finished - unbooting scenario"
  end

  # Boots {Cloud}, and all of its {Subnet Subnets}.
  # Creates a AWS::EC2::VPC object with Subnet's cidr_block
  # @return [nil]
  def aws_boot_cloud(options = {})
    self.set_booting
    debug "booting Cloud #{self.id}"
    self.set_booting

    # create vpc
    debug "creating VPC"
    begin
      ec2vpc = AWS::EC2.new.vpcs.create(self.cidr_block)
    rescue => e
      self.boot_error(e)
      return
    end

    # assign driver_id
    debug "assigning - VPC #{self.id} driver_id"
    begin
      self.update_attributes(driver_id: ec2vpc.id)
    rescue => e
      self.boot_error(e)
      return
    end

    # create internet gateway
    debug "creating - Internet Gateway"
    begin
      ec2vpc.internet_gateway = AWS::EC2.new.internet_gateways.create
    rescue => e
      self.boot_error(e)
      return
    end

    # wait for VPC to become available, erorr if timeout
    begin
      cnt = 0
      until ec2vpc.state == :available
        debug "waiting for - VPC #{self.driver_id} to become available"
        sleep 2**cnt
        cnt += 1
        if cnt == 8
          raise "Timeout Waiting for VPC to become available"
          self.boot_error($!)
          return
        end
      end
    rescue => e
      self.boot_error(e)
      return
    end

    debug "creating - Firewall rules"
    begin
      # Hardcoded firewall rules - TODO
      ec2vpc.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
      ec2vpc.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
      ec2vpc.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
      ec2vpc.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
      # TODO -- SECURITY -- delayed job in 20 min disable firewall.
      ec2vpc.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
    rescue => e
      self.boot_error(e)
      return
    end

    debug "creating tags"
    begin
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

    rescue => e
      self.boot_error(e)
      return
    end

    debug "booted - Cloud #{self.driver_id}"
    self.set_booted

    if options[:boot_dependents]
      # boot Subnets
      self.subnets.each do |subnet|
        begin
          if options[:run_asynchronously]
            subnet.delay(queue: 'subnets').boot(options)
          else
            subnet.boot(options)
          end
        rescue => e
          self.boot_error(e)
          return
        end
      end
    end

    # debug "cloud #{self.name} waiting for subnets to finish booting"
    # until not self.subnets_booting?
    #   sleep 2
    #   self.reload
    # end

    # begin
    #   if self.subnets_boot_failed?
    #     raise "subnets failed"
    #   end
    # rescue => e
    #   self.boot_error(e)
    #   return
    # end
  end

  def aws_unboot_cloud(options = {})
    self.set_unbooting

    if self.driver_id == nil
      self.set_stopped
      return
    end

    # check for dependents
    # self.dependents_booted?

    debug "unbooting - Cloud #{self.id}"

    if options[:unboot_dependents]

      self.subnets.each do |subnet|
        begin
          if options[:run_asynchronously]
            subnet.set_unbooting
            subnet.delay(queue: 'subnets').unboot(options)
          else
            subnet.unboot(options)
          end
        rescue => e
          self.unboot_error(e)
          return
        end
      end

      debug "wating - for subnets to unboot"
      until not self.subnets_unbooting?
        sleep 2
        self.reload
      end

      begin
        if self.subnets_unboot_failed?
          raise "subnets unboot failed"
        end
      rescue => e
        self.unboot_error(e)
      end

    else
      if self.subnets_booted?
        begin
          raise "Subnets not unbooted"
        rescue => e
          self.unboot_error(e)
          return
        end
      end
    end

    debug "getting - EC2 Cloud #{self.driver_id}"
    begin
      vpc = AWS::EC2.new.vpcs[self.driver_id]
    rescue => e
      self.unboot_error(e)
      return
    end

    if vpc.internet_gateway and vpc.internet_gateway.exists?
      igw = vpc.internet_gateway

      debug "detaching - InternetGateway #{vpc.internet_gateway.internet_gateway_id}"
      begin
        vpc.internet_gateway.detach(vpc)
      rescue => e
        self.unboot_error(e)
        return
      end

      debug "deleting - EC2 InternetGateway #{igw.internet_gateway_id}"
      begin
        igw.delete
      rescue => e
        self.unboot_error(e)
        return
      end

    end

    vpc.network_acls.select{ |acl| !acl.default}.each do |acl|
      aws_unboot_acl_new(acl, self)
    end

    vpc.security_groups.select{ |sg| !sg.name == "default"}.each do |security_group|
      aws_unboot_security_group_new(security_group, self)
    end

    vpc.route_tables.select{ |rt| !rt.main?}.each do |route_table|
      aws_unboot_route_table_new(route_table, self)
    end

    begin
      network_acls = vpc.network_acls
    rescue => e
      self.unboot_error(e)
      return
    end

    debug "unbooting - VPC #{self.driver_id}"
    begin
      vpc.delete
    rescue AWS::EC2::Errors::DependencyViolation => e
      if aws_instances_stopping?(self.scenario.instances)
        sleep 2
        retry
      else
        self.unboot_error(e)
        return
      end
    rescue => e
      self.unboot_error(e)
      return
    end

    self.driver_id = nil
    self.clear_log
    self.save
    self.set_stopped
  end

  # Boots {Subnet}, and all of its {Instance Instances}.
  # Creates a AWS::EC2::Subnet object, taking Subnet's `cidr_block` and the `VPC ID` of the {Cloud} the {Subnet} resides in.
  # @return [nil]
  def aws_boot_subnet(options = {})
    debug "booting - Subnet #{self.id}"
    self.set_booting

    # create Subnet
    debug "creating - EC2 Subnet"
    begin
      ec2subnet = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id)
    rescue => e
      self.boot_error(e)
      return
    end

    # set driver_id
    debug "assigning - Subnet #{self.id} driver_id"
    begin
      self.update_attributes(driver_id: ec2subnet.id)
    rescue => e
      self.boot_error(e)
      return
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
          return
        end
      end
    rescue AWS::EC2::Errors::InvalidSubnetID::NotFound
      debug "invalid subnet id - trying again"
      retry
    rescue => e
      self.boot_error(e)
      return
    end

    # do routing 
    debug "creating - EC2 RouteTable for #{self.driver_id}"
    begin
      ec2route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: self.cloud.driver_id)
    rescue => e
      self.boot_error(e)
      return
    end

    debug "assigning - EC2 Route Table #{ec2route_table.id} to EC2 Subnet #{self.driver_id}"
    begin
      ec2subnet.route_table = ec2route_table
    rescue => e
      self.boot_error(e)
      return
    end

    debug "getting - EC2 Cloud #{self.cloud.driver_id}"
    begin
      ec2cloud = AWS::EC2.new.vpcs[self.cloud.driver_id]
    rescue => e
      self.boot_error(e)
      return
    end

    if self.internet_accessible
      debug "creating - Internet Accessible RouteTable for EC2 Subnet #{self.driver_id}"
      begin
        ec2route_table.create_route("0.0.0.0/0", { internet_gateway: ec2cloud.internet_gateway} )
      rescue => e
        self.boot_error(e)
        return
      end
    end

    # can only do this once instances are done
    # else
    #   debug "creating - Route for EC2 Subnet #{self.driver_id} to NAT"
    #   begin
    #     ec2route_table.create_route("0.0.0.0/0", { instance: self.cloud.scenario.instances.select{|i| i.internet_accessible}.first.driver_id } )
    #   rescue
    #     raise
    #     return
    #   end
    # end

    debug "booted - Subnet #{self.driver_id}"
    if options[:boot_dependents]
      self.instances.select{ |i| !i.driver_id}.each do |instance|
        begin
          if options[:run_asynchronously]
            instance.delay(queue: 'instances').boot(options)
          else
            instance.boot(options)
          end
        rescue => e
          self.boot_error(e)
          return
        end
      end
    end

    # debug "subnet #{self.name} waiting for instances to finish booting"
    # until not self.instances_booting?
    #   sleep 2
    #   self.reload
    # end

    # begin
    #   if self.instances_boot_failed?
    #     raise "instances failed"
    #   end
    # rescue => e
    #   self.boot_error(e)
    #   return
    # end

    debug "creating tag"
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
      return
    end

    self.set_booted
  end

  def aws_unboot_subnet(options = {})
    self.set_unbooting

    # only unboot if instances are not booted
    if self.driver_id == nil
      self.set_stopped
      return
    end

    debug "unbooting - Subnet #{self.id}"

    if options[:unboot_dependents]
      self.instances.each do |instance|
        if instance.driver_id
          if options[:run_asynchronously]
            instance.set_unbooting
            instance.delay(queue: 'instances').unboot
          else
            instance.unboot
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
      end

    else

      # if not unbooting dependents make sure no instances are booted
      if self.instances_booted?
        begin
          raise "Instances not unbooted"
        rescue => e
          self.unboot_error(e)
          return
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
      return
    end

    # debug "deleting - subnets route table"
    # begin
    #   AWS::EC2.new.subnets[self.driver_id].route_table.delete
    # rescue => e
    #   self.unboot_error(e)
    #   return
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
        return
      end
    rescue => e
      self.unboot_error(e)
      return
    end

    self.driver_id = nil
    self.clear_log
    self.set_stopped
    self.save
  end

  # # Boots {Instance}, generating required cookbooks and startup scripts.
  # # This method largely defers to {InstanceTemplate} in order to generate shell scripts and
  # # chef scripts to configure each instance.
  # # Additionally, it uploads and stores the cookbook_url, which is generated by calling {#aws_instance_upload_cookbook}
  # # @return [nil]
  def aws_boot_instance(options = {})
    self.set_booting
    debug "booting - Instance #{self.name}"

    # create intitiation scripts
    debug "creating - Instance init"
    begin
      debug "generating - instance cookbook"
      self.aws_upload_com_page
      instance_template = InstanceTemplate.new(self)
      cookbook_text = instance_template.generate_cookbook_new

      debug "uploading - instance cookbook"
      self.aws_instance_upload_cookbook(cookbook_text)
      
      # self.update(cookbook_url: aws_S3_create_page(self.s3_name_prefix + '-cookbook', :read, cookbook_text))

      debug "generating - instance chef solo"
      cloud_init = instance_template.generate_cloud_init(self.cookbook_url)
    rescue => e
      self.boot_error(e)
      return
    end

    # get ami based on OS
    if self.os == 'ubuntu'
      # aws_instance_ami = 'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
      # aws_instance_ami = 'ami-1ea3d176'
      # aws_instance_ami = 'ami-56e7953e'
      # aws_instance_ami = 'ami-d2ec9eba'
      aws_instance_ami = 'ami-b80b76d0'
    elsif self.os == 'nat'
      # aws_instance_ami = 'ami-51727d38' # Private NAT image with chef and deps, updates etc.
      aws_instance_ami = 'ami-7092d118'
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
      self.update_attributes(driver_id: ec2instance.id)
      debug "updated instance attribute - #{self.driver_id}"
    rescue NoMethodError => e
      debug "- NoMethodError"
      self.boot_error(e)
      return
    rescue AWS::EC2::Errors::InvalidParameterCombination => e
      debug "- InvalidParameterCombination"
      # wrong instance type
      self.boot_error(e)
      return
    rescue AWS::EC2::Errors::InvalidSubnetID::NotFound => e
      debug "- InvalidSubnet"
      tries += 1
      if tries > 3
        self.boot_error(e)
        return
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
        return
      end
    rescue AWS::EC2::Errors::Unsupported => e
      debug "- Unsupported"
      tries += 1
      if tries > 3
        self.boot_error(e)
        return
      end
      sleep 10
      retry
    rescue => e
      debug "- Other Error"
      self.boot_error(e)
      return
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
          return
        end
      end
    rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
      if tries > 5
        self.boot_error(e)
        return
      end
      tries += 1
      sleep 3
      retry
    rescue => e
      self.boot_error(e)
      return
    end

    # for Internet Accessible instances
    if self.internet_accessible
      # create Elastip IP
      debug "creating - EC2 Elastic IP"
      begin
        ec2eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      rescue => e
        self.boot_error(e)
        return
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
          return
        end
      end

      # associate instance with EIP
      debug "associating - EC2 Elastip IP with EC2 Instance #{ec2instance.id}"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
      rescue => e
        self.boot_error(e)
        return
      end

      # accept packets coming in
      debug "accepting - EC2 Instance NIC packets, disabe source dest checks"
      begin
        ec2instance.associate_elastic_ip(ec2eip)
        ec2instance.network_interfaces.first.source_dest_check = false
      rescue => e
        self.boot_error(e)
        return
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
        return
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
      return
    end

    self.set_booted
    self.save
    debug "[x] booted - Instance #{self.name}"
  end

  def aws_unboot_instance(options = {})
    self.set_unbooting
    debug "unbooting - Instance #{self.name}"

    debug "getting - EC2 Instance #{self.driver_id}"
    begin
      ec2instance = AWS::EC2.new.instances[self.driver_id]
    rescue => e
      self.unboot_error(e)
      return
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
      return
    end

    debug "deleting any - EC2 Instance EIP's"
    begin
      if ec2eip = ec2instance.elastic_ip
        ec2instance.disassociate_elastic_ip
        ec2eip.delete
      end
    rescue => e
      self.unboot_error(e)
      return
    end

    debug "deleting - EC2 Instance #{self.driver_id}"
    begin
      ec2instance.delete
    rescue => e
      self.unboot_error(e)
      return
    end

    debug "stopping - EC2 Instance #{self.driver_id}"
    self.save

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
          return
        end
      end
    rescue => e
      self.unboot_error(e)
      return
    end

    # remove s3 files
    begin
      aws_S3_delete_page(uuid)
      aws_S3_delete_page(self.name + '-' + self.uuid + '-com')
    rescue => e
      self.unboot_error(e)
      return
    end

    self.driver_id = nil
    self.set_stopped
    self.clear_log
    self.save
    debug "unbooted - Instance #{self.name}"
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
      if cnt < 3
        sleep 1
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

  def aws_S3_create_page(name, permissions, content)
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[name].write(content) if content
      return bucket.objects[name].url_for(permissions, expires: 10.hours, :content_type => 'text/plain').to_s
      # self.update(com_page: bucket.objects[name].url_for(permissions, expires: 10.hours, :content_type => 'text/plain').to_s)
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

  def aws_upload_com_page
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      name = self.name + '-' + self.uuid + '-com'
      bucket.objects[name].write("waiting")
      self.update(com_page: bucket.objects[name].url_for(:write, expires: 10.hours, :content_type => 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  def aws_scenario_upload_com_page
    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      name = self.uuid + '-com'
      bucket.objects[name].write("ready")
      # bucket.objects[name].acl = :public_read
      # puts bucket.objects[name].url_for(:read, expires: 10.hours, :content_type => 'text/plain')
      # self.update(com_page: bucket.objects[name].url_for(:read, expires: 10.hours, content_type: 'text/plain').to_s)
      self.update(com_page: bucket.objects[name].url_for(:write, expires: 10.hours, content_type: 'text/plain').to_s)
    rescue
      raise
      return
    end
  end

  # This uploads our chef cookbook into S3, and gets us a url. This is given to the shell script
  # which sets a cron job to download and run the chef recipe.
  # @param cookbook_text The text to upload to S3
  # @return [String] A URL generated from S3 pointing to our text
  def aws_instance_upload_cookbook(cookbook_text)
    begin 
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      s3.buckets.create(Settings.bucket_name) unless bucket.exists?
      bucket.objects[uuid].write(cookbook_text)
      self.update(cookbook_url: bucket.objects[uuid].url_for(:read, expires: 10.hours).to_s)
    rescue
      raise
      return
    end
  end

  def aws_scenario_upload_scoring_pages
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name + '-edurange-scoring']
    s3.buckets.create(Settings.bucket_name + '-edurange-scoring') unless bucket.exists?
    name = self.name + "-" + self.uuid + "-scoring-pages"
    self.update(scoring_pages: bucket.objects[name].url_for(:read, expires: 10.hours).to_s)
  end

  def aws_scenario_write_to_scoring_pages
    AWS::S3.new.buckets[Settings.bucket_name + '-edurange-scoring'].objects[self.name + "-" + self.uuid + "-scoring-pages"].write(self[:scoring_pages_content])
  end

  def aws_scenario_upload_answers
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name + '-edurange-answers']
    s3.buckets.create(Settings.bucket_name + '-edurange-answers') unless bucket.exists?
    object = bucket.objects[self.name]
    object.write(self.answers)
    self.update(answers_url: object.url_for(:read, expires: 10.hours).to_s)
  end

  def aws_upload_scoring_url
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name + '-edurange-scoring']
    s3.buckets.create(Settings.bucket_name + '-edurange-scoring') unless bucket.exists?
    name = self.uuid + "-scoring-" + self.name
    bucket.objects[name].write("# put your answers here")
    self.update(scoring_url: bucket.objects[name].url_for(:write, expires: 10.hours, :content_type => 'text/plain').to_s)
  end

  def aws_delete_scoring_url
    name = self.uuid + "-scoring-" + self.name
    AWS::S3.new.buckets[Settings.bucket_name + '-edurange-scoring'].objects[name].delete
  end

  def aws_upload_scoring_page
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name + '-edurange-scoring']
    s3.buckets.create(Settings.bucket_name + '-edurange-scoring') unless bucket.exists?
    self.update(scoring_page: bucket.objects[self.uuid + "-scoring-" + self.name].url_for(:read, expires: 10.hours).to_s)
  end

  def aws_delete_scoring_page
    name = self.uuid + "-scoring-" + self.name
    AWS::S3.new.buckets[Settings.bucket_name + '-edurange-scoring'].objects[name].delete
  end

end
