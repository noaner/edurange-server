if Settings.ec2_key.blank?
  raise "Fatal error: ec2_key not provided"
end
module Edurange
  def self.ec2
    AWS::EC2.new
  end
  attr_accessor :nat_instance # global nat instance. assumes there is only one
  class Scenario
    def final_setup
      info "=== Final setup."
      # Anything that needs to be performed when the environment is 100% up.

      # Currently assumes there is only one NAT.
      Subnet.all.each do |subnet|
        @route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: subnet.cloud.driver_id)
        info "[x] AWS_Driver::create_route_table #{@route_table}"
        subnet.driver_object.route_table = @route_table
        if subnet.internet_accessible
          # Route traffic straight to internet, avoid the NAT
          info "NOTE: Subnet.all.each. Subnet #{subnet} adding route to igw"
          @route_table.create_route("0.0.0.0/0", { internet_gateway: subnet.cloud.igw} )
        else
          info "NOTE: Subnet.all.each. Subnet #{subnet} adding route to NAT"
          # Find the NAT instance
          @route_table.create_route("0.0.0.0/0", { instance: Edurange.nat_instance.driver_id} )
        end
      end
      Cloud.first.driver_object.security_groups.first.authorize_ingress(:tcp, 20..8080) #enable all traffic inbound from port 20 - 8080 (most we care about)
      Cloud.first.driver_object.security_groups.first.revoke_egress('0.0.0.0/0') # Disable all outbound
      Cloud.first.driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 80)  # Enable port 80 outbound
      Cloud.first.driver_object.security_groups.first.authorize_egress('0.0.0.0/0', protocol: :tcp, ports: 443) # Enable port 443 outbound
      Cloud.first.driver_object.security_groups.first.authorize_egress('10.0.0.0/16') # enable all traffic outbound to subnets
    end
  end
  class InstanceTemplate
    # Must set self.filepath to s3/http/https url
    def provider_upload
      cookbook = self.generate_cookbook
      self.filepath = S3::upload(cookbook)
    end
  end
  class Cloud < ActiveRecord::Base
    def igw
      self.driver_object.internet_gateway
    end
    def driver_object
      AWS::EC2::VPCCollection.new[self.driver_id]
    end
    def booted?
      self.driver_object.state == :available
    end
    def provider_boot
      info self.inspect
      info "AWS_Driver::provider_boot - cloud"
      # Create VPC
      if self.cidr_block.nil?
        raise "Tried to create Cloud without enough information."
      end

      self.driver_id = Edurange.ec2.vpcs.create(self.cidr_block).id
      self.save
      info "[x] AWS_Driver::create_vpc #{@driver_id}"

      @igw = Edurange.ec2.internet_gateways.create
      info "[x] AWS_Driver::create_internet_gateway #{@igw.internet_gateway_id}"
      execute_when_booted do
        self.driver_object.internet_gateway = @igw
      end
    end
  end
  class Subnet < ActiveRecord::Base
    def booted?
      if (!self.driver_object)
        puts "NO DRIVER OBJECT #{@driver_id}"
      end
      self.driver_object.state == :available
    end
    def driver_object
      AWS::EC2::SubnetCollection.new[self.driver_id]
    end
    def allow_traffic(cidr, options)
      instances.each do |instance|
        instance.allow_traffic(cidr, options)
      end
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
    def provider_boot
      info "AWS_Driver::provider_boot - subnet"
      # Create Subnet
      if self.cidr_block.nil?
        raise "Tried to create Subnet without enough information."
      end
      self.driver_id = AWS::EC2::SubnetCollection.new.create(self.cidr_block, vpc_id: self.cloud.driver_id).id
      self.save
      info self.inspect
      info "[x] AWS_Driver::create_subnet #{self.driver_id}"
      sleep 5

    end
  end
  class Instance < ActiveRecord::Base
    def driver_object
      AWS::EC2::InstanceCollection.new[self.driver_id]
    end
    def booted?
      self.driver_object.status == :running
    end
    def booting?
      self.driver_object.status == :pending
    end
    def shutting_down?

    end
    def stopped?
      self.driver_object.status == :stopped
    end
    def nat?
      @internet_accessible
    end
    def ami_id
      if self.os == 'ubuntu'
        'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
      elsif self.os == 'nat'
        'ami-51727d38' # Private NAT image with chef and deps, updates etc.
      end
    end
    def upload_cookbook(cookbook_text)
      # Set self.cookbook_url = S3 url, save, return cookbook url
      s3 = AWS::S3.new
      bucket = s3.buckets['edurange']
      unless bucket.exists?
        s3.buckets.create('edurange')
      end
      uuid = `uuidgen`
      bucket.objects[uuid].write(cookbook_text)
      cookbook_url = bucket.objects[uuid].url_for(:read, expires: 1000).to_s # 1000 minutes
      self.update_attributes(cookbook_url: cookbook_url)
      return cookbook_url
    end

    def provider_boot
      info "AWS_Driver::provider_boot - instance"
      instance_template = InstanceTemplate.new(self)
      cookbook_text = instance_template.generate_cookbook
      self.cookbook_url = self.upload_cookbook(cookbook_text)
      cloud_init = instance_template.generate_cloud_init(self.cookbook_url)
      puts self.cookbook_url
      self.driver_id = AWS::EC2::InstanceCollection.new.create(
                                                               image_id: self.ami_id, # ami_id string of os image
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
      info self.inspect

      if self.internet_accessible
        Edurange.nat_instance = self
        execute_when_booted do
          eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
          info "AWS_Driver:: Allocated EIP #{eip}"
          self.driver_object.associate_elastic_ip eip
          self.driver_object.network_interfaces.first.source_dest_check = false # Set first NIC (assumption) to not check source/dest. Required to accept other machines' packets
        end
      end

      # self.cloud.driver_object.security_groups.first.authorize_ingress(:tcp, 0..64555)
      # Create security group.
      # TODO figure out how to only enable inbound tcp on the NAT instance



    end
    def allow_traffic(cidr, options)
      # cidr = '10.0.0.0/24'
      # options = { all: :all, tcp: :ssh, ...}
    end
  end
end
