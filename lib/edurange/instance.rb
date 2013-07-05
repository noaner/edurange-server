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
        @aws_object = @subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, subnet: subnet)
        debug "AWS Returned #{@aws_object}"
      else
        @aws_object = @subnet.instances.create(image_id: @ami_id, key_pair: @key_pair, user_data: puppet_setup_script, private_ip_address: @ip_address, subnet: subnet)
      end
      if @is_nat
        debug "Nat instance: #{@aws_object}"

        sleep_until_running

        @aws_object.network_interfaces.first.source_dest_check = false
        nat_eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
        @aws_object.associate_elastic_ip nat_eip
        info "NAT EIP: " + nat_eip
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

