class Management
  def debug(message)
    # PrivatePub.publish_to "/cleanup", log_message: message
  end
  def purge
    Scenario.delete_all
    Cloud.delete_all
    Subnet.delete_all
    Instance.delete_all
    Player.delete_all
    Group.delete_all
    Role.delete_all
    InstanceGroup.delete_all
    InstanceRole.delete_all
    debug "Finished purging local DB!"
  end
  handle_asynchronously :purge

  def showresources
    puts Scenario.all
    puts Cloud.all
    puts Subnet.all
    puts Instance.all
    puts Player.all
    puts Group.all
    puts Role.all
    puts InstanceGroup.all
    puts InstanceRole.all
  end

  def cleanup
    ec2 = AWS::EC2.new
    vpc_collect = ec2.vpcs

    vpc_collect.each do |vpc|

      vpc.security_groups.each do |security_group|
        unless security_group.name == "default"
          debug "Deleting security group #{security_group}"
          security_group.delete
          if security_group.exists?
            debug "Waiting for #{security_group} to terminate "
            while security_group.exists?
              debug ".. "
              sleep(2)
            end
            debug " OK\n"
          end
        end
      end

      vpc.instances.each do |inst|

        if inst.has_elastic_ip?
          eip = inst.elastic_ip
          debug "Disassociating Elastic IP for #{inst}"
          inst.disassociate_elastic_ip
          eip.delete

          if eip.exists?
            debug "Waiting for Elastic IP to terminate "
            while eip.exists?
              debug ".. "
              sleep(2)
            end
            debug " OK\n"
          end
        end

        debug "Deleting instance #{inst}"
        inst.delete
        if inst.exists?
          debug "Waiting for Instance #{inst} to terminate "
          unless inst.status == :terminated then
            debug ".. "
            sleep(2)
          end
          debug " OK\n"
        end
      end

      if vpc.subnets
        vpc.subnets.each do |subnet|
          debug "Deleting subnet #{subnet}"
          begin
            # this causes a lot of dependancy violation errors
            subnet.delete

            unless subnet.state != :pending
              sleep(2)
            end

          rescue Exception => e
            debug e.message
            if subnet.instances
              subnet.instances.each { |inst|
                debug "#{inst} on subnet #{subnet}'s status is #{inst.status}"
              }
            end
            debug "EDURange cleanup will keep going anyway."
          end
        end
      end


      vpc.route_tables.each do |route_table|
        unless route_table.main?
          debug "Deleting route table #{route_table.id}"

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
        debug "Deleting internet gateway #{vpc.internet_gateway.internet_gateway_id}"
        igw.detach(vpc)
        igw.delete
      end

      unless vpc.dhcp_options == nil then
        dhcp_opt = vpc.dhcp_options
        unless dhcp_opt.id == "default"
          debug "Deleting dhcp options #{dhcp_opt.id} from vpc #{vpc.id}"

          if dhcp_opt.vpcs
            dhcp_opt.vpcs.each { |vpc|
              vpc.dhcp_options = 'default'
            }
          end

          dhcp_opt.delete
        end
      end


      unless vpc.vpn_gateway == nil then
        debug "Deleting internet gateway #{vpc.vpn_gateway.id}"
        vpc.vpn_gateway.delete
      end

      vpc.network_acls.each do |network_acl|
        unless network_acl.default? then
          debug "Deleting network acl #{network_acl.id}"
          network_acl.delete
        end
      end

      debug "Deleting VPC #{vpc}"
      # this delete causes a lot of errors
      begin
        vpc.delete

      rescue Exception => e
        debug e.message
        debug "EDURange cleanup will try again now."
        cleanup
      end

    end

    vol_collect = ec2.volumes

    vol_collect.each do |volume|
      if volume.status == :available then
        debug "Deleting volume #{volume.id}"
        volume.delete
      end
    end

    elastic_ip_collect = ec2.elastic_ips

    elastic_ip_collect.each do |elastic_ip|
      debug "Deleting elastic ip #{elastic_ip}"
      elastic_ip.delete
    end
  end
  handle_asynchronously :cleanup
end
