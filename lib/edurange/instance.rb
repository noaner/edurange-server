module Edurange
  class Instance
    attr_accessor :name, :ami_id, :ip_address, :key_pair, :users, :uuid, :facts, :subnet

    def initialize
      @instance_id = nil
      @running = false
      @key_pair = AWS::EC2::KeyPairCollection.new[Settings.ec2_key]
      @users = []
    end

    def startup
      # Get the subnet we should be a part of (doesn't actually create the subnet)
      subnet = AWS::EC2::Subnet.new @subnet_id

      if @ami_id.nil? || @subnet.nil? || @uuid.nil?
        raise "Tried to start instance without enough information."
      end

      # Set up puppetmaster to handle our instance

      # Take facts, write to /etc/facter.d/

      # Take users, write to manifest

      puts "Spinning up instance at subnet #{@subnet.id} - #{@ip_address}"
      # Actually run instance
      puppet_setup_script = Helper.puppet_setup_script(@uuid)

      if @ip_address.nil?
        @subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, subnet: subnet)
      else
        @subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, private_ip_address: @ip_address, subnet: subnet)
      end
    end

    def to_s
      "<Edurange::Instance name:#{@name} ami_id: #{@ami_id} ip: #{@ip_address} key: #{@key_pair} running: #{@running} instance_id: #{@instance_id}>"
    end


  end
end

