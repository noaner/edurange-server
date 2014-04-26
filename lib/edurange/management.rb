module Edurange
  class Management
    def self.cleanup

      ec2 = AWS::EC2.new
      vpc_collect = ec2.vpcs

      vpc_collect.each do |vpc|

	vpc.security_groups.each do |security_group|
	  unless security_group.name == "default"
	    puts "Deleting security group #{security_group}"
	    security_group.delete
	    if security_group.exists?
	      $stdout.write("Waiting for #{security_group} to terminate ")
	      while security_group.exists?
		$stdout.write(".. ")
		sleep(2)
	      end
	      puts " OK\n"
	    end
	  end
	end

	vpc.instances.each do |inst|

	  if inst.has_elastic_ip?
	    eip = inst.elastic_ip
	    puts "Disassociating Elastic IP for #{inst}"
	    inst.disassociate_elastic_ip
	    eip.delete

	    if eip.exists?
	      $stdout.write("Waiting for Elastic IP to terminate ")
	      while eip.exists?
		$stdout.write(".. ")
		sleep(2)
	      end
	      puts " OK\n"
	    end
	  end

	  puts "Deleting instance #{inst}"
	  inst.delete
	  if inst.exists?
	    $stdout.write("Waiting for Instance #{inst} to terminate ")
	    unless inst.status == :terminated then
	      $stdout.write(".. ")
	      sleep(2)
	    end
	    puts " OK\n"
	  end
	end

	if vpc.subnets
	  vpc.subnets.each do |subnet|
	    puts "Deleting subnet #{subnet}" 
	    begin
	      # this causes a lot of dependancy violation errors
	      subnet.delete

	      unless subnet.state != :pending
		sleep(2)
	      end

	    rescue Exception => e
	      puts e.message
	      if subnet.instances
		puts "#{subnet}'s instance statuses are as follows:"
		subnet.instances.each { |inst|
		  puts "#{inst} status = #{inst.status}"
		}
	      end
	      puts "EDURange cleanup will keep going anyway."
	    end
	  end
	end


	vpc.route_tables.each do |route_table|
	  unless route_table.main?
	    puts "Deleting route table #{route_table.id}"

	    if route_table.subnets 
	      route_table.subnets.each do |subnet|
		subnet.set_route_table(ec2.route_tables.main_route_table)
	      end
	    end

	    route_table.delete
	  end
	end

	unless vpc.internet_gateway == nil then
	  igw = vpc.internet_gateway
	  puts "Deleting internet gateway #{vpc.internet_gateway.internet_gateway_id}"
	  igw.detach(vpc)
	  igw.delete
	end

	unless vpc.dhcp_options == nil then
	  dhcp_opt = vpc.dhcp_options
	  unless dhcp_opt.id == "default"
	    puts "Deleting dhcp options #{dhcp_opt.id} from vpc #{vpc.id}"

	    if dhcp_opt.vpcs
	      dhcp_opt.vpcs.each { |vpc|
		vpc.dhcp_options = 'default'
	      }
	    end

	    dhcp_opt.delete
	  end
	end


	unless vpc.vpn_gateway == nil then
	  puts "Deleting internet gateway #{vpc.vpn_gateway.id}"
	  vpc.vpn_gateway.delete
	end

	vpc.network_acls.each do |network_acl|
	  unless network_acl.default? then
	    puts "Deleting network acl #{network_acl.id}"
	    network_acl.delete
	  end
	end

	puts "Deleting VPC #{vpc}"
	# this delete causes a lot of errors
	begin
	  vpc.delete

	rescue Exception => e
	  puts e.message
	  puts "EDURange cleanup will try again now."
	  self.cleanup
	end

      end

      vol_collect = ec2.volumes

      vol_collect.each do |volume|
	if volume.status == :available then
	  puts "Deleting volume #{volume.id}"
	  volume.delete
	end
      end

      elastic_ip_collect = ec2.elastic_ips

      elastic_ip_collect.each do |elastic_ip|
	puts "Deleting elastic ip #{elastic_ip}"
	elastic_ip.delete
      end
      return
    end




