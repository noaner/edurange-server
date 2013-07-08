module Edurange
  class Cloud
    # Internal object representation of AWS VPCs
    # This is OK to do at the moment, as our YAML file contains a "VPC_Mask" declaration

    attr_accessor :aws_object, :cidr_block, :igw, :nat_instance
    attr_reader :subnets
    def initialize
      @subnets = []
    end

    def add(subnet)
      subnet.cloud = self
      @subnets.push subnet
    end

    def vpc_id
      if @aws_object
        @aws_object.id
      else
        nil
      end
    end

    def startup
      if @cidr_block.nil?
        raise "Tried to create Cloud without enough information."
      end

      vpc_request = Edurange.ec2.create_vpc(cidr_block: @cidr_block)
      @aws_object = AWS::EC2::VPCCollection.new[vpc_request[:vpc][:vpc_id]]

      sleep_until_running

      igw_request = Edurange.ec2.create_internet_gateway
      @igw = AWS::EC2::InternetGatewayCollection.new[igw_request[:internet_gateway][:internet_gateway_id]]
      @aws_object.internet_gateway = @igw

      info "Waiting for #{@igw.id} to be created"
      sleep 2 until @igw.exists?

      @aws_object.security_groups.first.authorize_ingress(:tcp, 0..64555)

      # Now that we have a vpc, instantiate all of our subnets
      @subnets.each do |subnet|
        subnet.startup
      end


    end
    def sleep_until_running
      info "Waiting for Cloud to spin up (~10 seconds)"
      sleep 3 while @aws_object.state == :pending
    end
  end
end
