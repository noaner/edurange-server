module Edurange
  class Management
    def self.cleanup
      ec2 = AWS::EC2.new
       
      # get an array of virtual private clouds
      vpc_collect = ec2.vpcs

      vpc_collect.each do |vpc|

        vpc.security_groups.each do |security_group|
          unless security_group.name == "default"
            security_group.delete
          end
        end

        vpc.instances.each do |inst|

          if inst.has_elastic_ip?
            eip = inst.elastic_ip
            inst.disassociate_elastic_ip
            eip.delete
          end

          inst.delete

          unless inst.status == :terminated then
            sleep(2)
          end

        end

        if vpc.subnets
          vpc.subnets.each { |subnet|
            subnet.delete
          }
        end

        if vpc.network_interfaces
          vpc.network_interfaces.each { |network_interface|
            network_interface.delete
          }
        end

        vpc.route_tables.each do |route_table|
          unless route_table.main?
            route_table.delete
          end
        end

        unless vpc.internet_gateway == nil then
          igw = vpc.internet_gateway
          igw.detach(vpc)
          igw.delete
        end

        unless vpc.dhcp_options == nil then
          dhcp_opt = vpc.dhcp_options
          vpc.dhcp_options = 'default'
          unless dhcp_opt.id == "default"
            dhcp_opt.delete
          end
        end

        unless vpc.vpn_gateway == nil then
          vpc.vpn_gateway.delete
        end

        vpc.network_acls.each do |network_acl|
          unless network_acl.default? then
            network_acl.delete
          end
        end

        vpc.delete

      end

      vol_collect = ec2.volumes

      vol_collect.each do |volume|
        unless volume.status == :in_use then
          volume.delete
        end
      end

      elastic_ip_collect = ec2.elastic_ips

      elastic_ip_collect.each {|elastic_ip|
        elastic_ip.delete
      }

    end
  end
end
