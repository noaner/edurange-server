module Edurange
  class Instance
    attr_accessor :name, :ami_id, :ip_address, :key_pair, :users, :uuid, :facts, :subnet, :is_nat

    def initialize
      @instance_id = nil
      @running = false
      @key_pair = AWS::EC2::KeyPairCollection.new[Settings.ec2_key]
      @users = []
      @is_nat = false
      @aws_object = nil
    end

    def startup
      if @ami_id.nil?
        raise "Tried to create Instance, but AMI ID is nil"
      elsif @subnet.nil?
        raise "Tried to create Instance, but Subnet is nil"
      elsif @uuid.nil?
        raise "Tried to create Instance, but UUID is nil"
      end


      # Set up puppetmaster to handle our instance

      # Take facts, write to /etc/facter.d/

      # Take users, write to manifest

      # Actually run instance
      puppet_setup_script = Helper.puppet_setup_script(@uuid)

      if @ip_address.nil?
        @aws_object = AWS::EC2::InstanceCollection.new.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, subnet: @subnet.subnet_id)
      else
        @aws_object = AWS::EC2::InstanceCollection.new.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, private_ip_address: @ip_address, subnet: @subnet.subnet_id)
      end
      @instance_id = @aws_object.id
      if @is_nat
        sleep_until_running

        @aws_object.network_interfaces.first.source_dest_check = false
        nat_eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)

        # Wait until EIP allocated
        sleep 2 until nat_eip.exists?

        @aws_object.associate_elastic_ip nat_eip
        info "NAT EIP: " + nat_eip.to_s
        @subnet.cloud.nat_instance = @aws_object
      end
    end

    def to_s
      "<Edurange::Instance name:#{@name} ami_id: #{@ami_id} ip: #{@ip_address} key: #{@key_pair} running: #{@running} instance_id: #{@instance_id}>"
    end

    def sleep_until_running
      info "Waiting for instance to spin up (~40 seconds)"
      sleep 5 while @aws_object.status == :pending
    end

  end
end

