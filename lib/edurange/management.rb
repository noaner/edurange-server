module Edurange
  class Management
    def self.cleanup
      ec2 = AWS::EC2.new
       
      # get an array of virtual private clouds
      vpc_collect = ec2.vpcs

      vpc_collect.each do |vpc|

        vpc.security_groups.each do |security_group|
          unless security_group.name == "default"
            puts "Deleting security group #{security_group}"
            security_group.delete
          end
        end

        vpc.instances.each do |inst|

          if inst.has_elastic_ip?
            eip = inst.elastic_ip
            puts "Disassociating Elastic IP for #{instance}"
            inst.disassociate_elastic_ip
            eip.delete
          end

          puts "Deleting instance #{instance}"
          inst.delete

          unless inst.status == :terminated then
            sleep(2)
          end

        end

        if vpc.subnets
          vpc.subnets.each { |subnet|
            puts "Deleting subnet #{subnet}" 
            begin
              subnet.delete
            rescue Exception => e
              puts e.message
              puts "#{subnet}'s instance statuses are as follows:"
              subnet.instances.each { |inst|
                puts "#{inst} status = #{inst.status}"
              }
            end
          }
        end

        if vpc.network_interfaces
          vpc.network_interfaces.each { |network_interface|
            puts "Deleting network interface #{network_interface.id}"
            network_interface.delete
          }
        end

        vpc.route_tables.each do |route_table|
          unless route_table.main?
            puts "Deleting route table #{route_table.id}"
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
          vpc.dhcp_options = 'default'
          unless dhcp_opt.id == "default"
            puts "Deleting dhcp options #{dhcp_opt.id} from vpc #{vpc.id}"
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
        vpc.delete

      end

      vol_collect = ec2.volumes

      vol_collect.each do |volume|
        unless volume.status == :in_use then
          puts "Deleting volume #{volume.id}"
          volume.delete
        end
      end

      elastic_ip_collect = ec2.elastic_ips

      elastic_ip_collect.each {|elastic_ip|
        puts "Deleting elastic ip #{elastic_ip}"
        elastic_ip.delete
      }

    end
  end
end
