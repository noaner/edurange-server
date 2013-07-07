module Edurange
  class Subnet
    attr_accessor :is_nat, :aws_object, :cidr_block, :cloud
    attr_reader :instances
    def initialize
      @is_nat = false
      @instances = []
    end

    def add(instance)
      instance.subnet = self
      @instances.push instance
    end

    def startup
      if @cidr_block.nil? 
        raise "Tried to create Subnet but cidr_block = #{@cidr_block}"
      elsif @cloud.nil?
        raise "Tried to create Subnet but cloud = #{@cloud}"
      end

      @aws_object = AWS::EC2::SubnetCollection.new.create(@cidr_block, vpc_id: @cloud.vpc_id)
      route_table = AWS::EC2::RouteTableCollection.new.create(vpc_id: @cloud.vpc_id)
      @aws_object.route_table = route_table
      if @is_nat
        # Create IGW, route traffic from instances to IGW
        route_table.create_route("0.0.0.0/0", { internet_gateway: @cloud.igw} )
      else
        route_table.create_route("0.0.0.0/0", { instance: @cloud.nat_instance } )
      end
    end

    def to_s
      "<Edurange::Subnet Nat? #{@is_nat} Instances: #{@instances.size}>"
    end
  end
end
