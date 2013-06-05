module Edurange
  class Instance
    attr_reader :name, :ami_id, :ip_address, :startup_script
    def initialize(name, ami_id, ip_address, key_pair, startup_script, subnet_id)
      @name = name
      @ami_id = ami_id
      @ip_address = ip_address
      @key_pair = key_pair
      @running = false
      @startup_script = startup_script
      @instance_id = nil
      @subnet_id = subnet_id
    end

    def startup
      # Get the subnet we should be a part of (doesn't actually create the subnet)
      subnet = AWS::EC2::Subnet.new @subnet_id

      puts "Spinning up instance at subnet #{@subnet_id} - #{@ip_address}"
      # Actually run instance
      if @ip_address.nil?
        subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: @startup_script, subnet: subnet)
      else
        subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: @startup_script, private_ip_address: @ip_address, subnet: subnet)
      end
    end

    def to_s
      "<Edurange::Instance name:#{@name} ami_id: #{@ami_id} ip: #{@ip_address} key: #{@key_pair} running: #{@running} instance_id: #{@instance_id}>"
    end


  end
end

