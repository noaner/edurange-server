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

      subnet = Edurange.vpc.subnets.create(@cidr_mask, vpc_id: vpc_id)
      route_table = Edurange.vpc.route_tables.create(vpc_id: vpc_id)
      subnet.route_table = route_table
      if @is_nat
        # Create IGW, route traffic from instances to IGW
        route_table.create_route("0.0.0.0/0", { internet_gateway: @cloud.igw} )
      else
        route_table.create_route("0.0.0.0/0", { instance: @cloud.nat_instance } )
      end
    end

    def to_s
      "<Edurange::Subnet Nat? #{@is_nat} Instances: #{@instances.size}"
    end
  end
end
