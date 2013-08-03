module Edurange
  class Subnet
    attr_accessor :is_nat, :aws_object, :cidr_block, :cloud, :route_table
    attr_reader :instances
    def initialize
      @is_nat = false
      @instances = []
      @route_table = nil
    end

    def add(instance)
      instance.subnet = self
      @instances.push instance
    end

    def subnet_id
      @aws_object.id
    end

    def startup
      if @cidr_block.nil? 
        raise "Tried to create Subnet but cidr_block = #{@cidr_block}"
      elsif @cloud.nil?
        raise "Tried to create Subnet but cloud = #{@cloud}"
      end

      @aws_object = AWS::EC2::SubnetCollection.new.create(@cidr_block, vpc_id: @cloud.vpc_id)
      @route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: @cloud.vpc_id)
      sleep_until_running
      @aws_object.route_table = route_table

      # Route traffic straight to internet, avoid the NAT
      @route_table.create_route("0.0.0.0/0", { internet_gateway: @cloud.igw} )

      # Create instances (But don't configure them with chef, etc)
      info "Creating Subnet's instances"
      @instances.each do |instance|
        instance.startup
      end


    end
    def configure_subnet
      # After all instances are created, configure them with chef.
      @instances.each do |instance|
        instance.configure_instance
      end

      # THEN clean up routes, route traffic through NAT
      unless @is_nat
        info "Cleaning up setup routes, routing to NAT"
        @route_table.delete_route("0.0.0.0/0")
        @route_table.create_route("0.0.0.0/0", { instance: @cloud.nat_instance.id } )
      end
    end

    def to_s
      "<Edurange::Subnet Nat? #{@is_nat} Instances: #{@instances.size}>"
    end
    def sleep_until_running
      info "Waiting for subnet to spin up (approx 3 seconds)"
      sleep 3
      sleep 1 until @aws_object.state == :available
    end
  end
end
