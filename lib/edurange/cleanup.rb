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

	if vpc.instances
		vpc.instances.each do |instance|
			instance.disassociate_elastic_ip
			instance.delete
		end
	end	

	if vpc.security_groups
		vpc.security_groups.each do |security_group|
			security_group.delete
		end
	end

	if vpc.instances
		vpc.instances.each do |instance|
			if instance.elastic_ip
				instance.disassociate_elastic_ip
			end
			instance.delete
		end
	end

	if vpc.subnets
		vpc.subnets.each do |subnet|
			subnet.delete
		end
	end

	if vpc.route_tables
		vpc.route_tables.each do |route_table|
			route_table.delete
		end
	end

	if vpc.network_interfaces
		vpc.network_interfaces.each do |network_interface|
			network_interface.delete
		end
	end

	if vpc.dhcp_options
		vpc.dhcp_options.each do |dhcp_option|
			dhcp_option.delete
		end
	end

	if vpc.internet_gateway
		vpc.internet_gateway.delete
		ec2.new.select { |ip| !ip.associated? }.each(&:release)
	end

	if vpc
		vpc.delete
	end
end
