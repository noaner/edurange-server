if Settings.ec2_key.blank?
  raise "Fatal error: ec2_key not provided"
end
module Edurange
  def self.ec2
    AWS::EC2.new
  end
  class Chef
    # Must return http/https/ftp link to cookbook zip
    def provider_upload
      s3 = ''
    end
  end
  class Cloud < ActiveRecord::Base
    def booted?
      puts @driver_object.status
    end
    def vpc_id
      if @driver_object
        @driver_object.id
      else
        nil
      end
    end
    def provider_boot
      info self.inspect
      info "AWS_Driver::provider_boot"
      # Create VPC
      if self.cidr_block.nil?
        raise "Tried to create Cloud without enough information."
      end

      @driver_object = Edurange.ec2.vpcs.create(self.cidr_block)
      debug "[x] AWS_Driver::create_vpc #{@driver_object}"

      @igw = Edurange.ec2.internet_gateways.create
      debug "[x] AWS_Driver::create_internet_gateway #{@igw}"
      execute_when_booted do
        @driver_object.internet_gateway = @igw
      end
    end
  end
  class Subnet < ActiveRecord::Base
    def allow_traffic(cidr, options)
      instances.each do |instance|
        instance.allow_traffic(cidr, options)
      end
    end
    def provider_boot
      info self.inspect
      info "AWS_Driver::provider_boot"
      # Create Subnet
      @driver_object = AWS::EC2::SubnetCollection.new.create(@cidr_block, vpc_id: @cloud.vpc_id)
      debug "[x] AWS_Driver::create_subnet #{@driver_object}"
      @route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: @cloud.vpc_id)
      debug "[x] AWS_Driver::create_route_table #{@route_table}"
      @cloud.driver_object.security_groups.first.authorize_ingress(:tcp, 0..64555)
      # TODO figure out how to only enable inbound tcp

      if @internet_accessible
        execute_when_booted do
          @aws_object.route_table = route_table
        
          # Route traffic straight to internet, avoid the NAT
          @route_table.create_route("0.0.0.0/0", { internet_gateway: @cloud.igw} )
        end
      end

    end
  end
  class Instance < ActiveRecord::Base
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

    def provider_boot
      # We need to:
      # - Create 1 instance
      @driver_object = AWS::EC2::InstanceCollection.new.create(image_id: @ami_id, private_ip_address: @ip_address, key_pair: @key_pair, subnet: @subnet.subnet_id)
      @eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      if @internet_accessible
        execute_when_booted do
          @driver_object.associate_elastic_ip @eip
          @driver_object.network_interfaces.first.source_dest_check = false # Set first NIC to not check source/dest. Required in AWS to accept other machines' packets
          @driver_object.network_interfaces
        end
      end
    end
    def allow_traffic(cidr, options)
      # cidr = '10.0.0.0/24'
      # options = { all: :all, tcp: :ssh, ...}
    end
  end
end
