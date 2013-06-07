require 'aws-sdk'

# Make new ec2 object
ec2 = AWS::EC2.new

# Make new ec2_client client object
ec2_client = AWS::EC2::Client.new

# Initialize arrays
vpc_ids = []

# Make an array of all vpc_ids and dhcp_option_ids
ec2_client.describe_vpcs[:vpc_set].each do |vpc|
	vpc_ids << vpc[:vpc_id]
end

# Heavy lifting using vpc_id to identify each vpc
vpc_ids.each do |vpc_id|
	vpc = AWS::EC2::VPCCollection.new[vpc_id]

	unless vpc.instances.nil?
		vpc.instances.each do |instance|
			instance.disassociate_elastic_ip
			instance.delete
		end
	end	

	unless vpc.security_groups.nil?
		vpc.security_groups.each do |security_group|
			security_group.delete
		end
	
	unless vpc.instances.nil?
		vpc.instances.each do |instance|
			if instance.elastic_ip
				instance.disassociate_elastic_ip
			end
			instance.delete
		end
	end


	unless vpc.subnets.nil?
		vpc.subnets.each do |subnet|
			subnet.delete
		end
	end

	unless vpc.route_tables.nil?
		vpc.route_tables.each do |route_table|
			route_table.delete
		end
	end

	unless vpc.network_interfaces.nil?
		vpc.network_interfaces.each do |network_interface|
			network_interface.delete
		end
	end

	unless vpc.dhcp_options.nil?
		vpc.dhcp_options.each do |dhcp_option|
			dhcp_option.delete
		end
	end

	unless vpc.internet_gateway.nil?
		vpc.internet_gateway.delete
		ec2.new.select { |ip| !ip.associated? }.each(&:release)
	end

	unless vpc.nil?
		vpc.delete
	end
end
