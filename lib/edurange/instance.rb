module Edurange
  class Instance
    attr_accessor :name, :ami_id, :ip_address, :elastic_ip, :key_pair, :users, :uuid, :facts, :subnet, :is_nat, :packages

    def initialize
      @instance_id = nil
      @running = false
      @key_pair = AWS::EC2::KeyPairCollection.new[Settings.ec2_key]
      @users = []
      @packages = []
      @is_nat = false
      @aws_object = nil
      @ip_address = nil
      @elastic_ip = nil
    end

    def configure_instance
      # Poll until ssh open
      configure_cookbooks

      sleep_until_running
      
      # Create, wait, and associate EIP
      @elastic_ip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
      sleep 2
      sleep 2 until @elastic_ip.exists?
      @aws_object.associate_elastic_ip @elastic_ip
      info "Elastic IP: " + @elastic_ip.to_s

      if @is_nat
        # Configure it so it does not drop packets
        @aws_object.network_interfaces.first.source_dest_check = false
        
        # Set Cloud's nat_instance to our object
        @subnet.cloud.nat_instance = @aws_object
      end
      sleep_until_configurable # MUST HAVE ELASTIC IP

      bootstrap_chef
    end

    def bootstrap_chef
      ip_address = @elastic_ip.ip_address
      # Bootstrap with chef
      if @is_nat
        ssh_user = 'ec2-user'
      else
        ssh_user = 'ubuntu'
      end

      knife_command = "knife bootstrap #{ip_address} -N #{@subnet.cloud.vpc_id}-#{@name} --ssh-user #{ssh_user} --sudo --run-list 'recipe[edurange_base],recipe[edurange_bootstrap_#{@subnet.cloud.vpc_id}_#{@name}]'"

      info "Creating #{knife_command}"
      Dir.chdir(Settings.chef_path) do
        puts "Knife output ======"
        puts `#{knife_command}`
        puts "END   output ======"
      end

      unless @is_nat
        @aws_object.disassociate_elastic_ip
        @elastic_ip.delete
        @elastic_ip = nil
      end
    end

    def configure_cookbooks
      # Create recipe
      cookbook_path = "edurange_bootstrap_#{@subnet.cloud.vpc_id}_#{@name}"
      Dir.chdir(Settings.chef_path + '/cookbooks/') do
        info "In #{Dir.getwd}"
        Dir.mkdir(Dir.getwd + "/" + cookbook_path)
        Dir.chdir(Dir.getwd + "/" + cookbook_path) do
          info "In #{Dir.getwd}"
          File.open('metadata.rb', 'w') do |file|
            file.puts "name  '#{cookbook_path}'"
            file.puts "maintainer 'Edurange'"
            file.puts "maintainer_email 'edurange2@gmail.com'"
            file.puts "license 'MIT'"
            file.puts "description 'bootstraps #{cookbook_path}'"
            file.puts "long_description 'no more'"
            file.puts "version 1.0"
            file.puts "recipe '#{cookbook_path}', 'Recipe for setting up instance'"
            file.puts "%w{ubuntu debian redhat centos fedora freebsd}.each { |os| supports os }"
          end
          recipes_path = "/recipes"
          info "making dir #{Dir.getwd + recipes_path}"
          Dir.mkdir(Dir.getwd + recipes_path)
          Dir.chdir(Dir.getwd + recipes_path) do
            File.open('default.rb', 'w') do |file|
              #@packages.each do |package|
                #file.puts "package '#{package}'"
              #end
              @users.each do |user|
                login = user["login"]
                gen_pub_ssh_key = user["generated_pub"]
                gen_priv_ssh_key = user["generated_priv"]
                file.puts "user_account '#{login}' do"
                file.puts "  password '$1$IX4FOOoL$Ui3SypXns9r1HuWAiWdsG.'" # Sets password to "password"
                file.puts "  ssh_keys ['#{gen_pub_ssh_key}']"
                unless @is_nat
                  file.puts "  gid 'admin'"
                end
                file.puts "  action :create"
                file.puts "end"
                file.puts "file '/home/#{login}/.ssh/id_rsa' do" # Sets priv key to generated one
                file.puts "  owner '#{login}'"
                file.puts "  content '#{gen_priv_ssh_key}'"
                file.puts "end"
              end
            end
          end
        end
        `knife upload /cookbooks -c #{Settings.knife_path}`
      end
    end

    def startup
      if @ami_id.nil?
        raise "Tried to create Instance, but AMI ID is nil"
      elsif @subnet.nil?
        raise "Tried to create Instance, but Subnet is nil"
      elsif @uuid.nil?
        raise "Tried to create Instance, but UUID is nil"
      end

      @aws_object = AWS::EC2::InstanceCollection.new.create(image_id: @ami_id, key_pair: @key_pair, private_ip_address: @ip_address, subnet: @subnet.subnet_id)
      @instance_id = @aws_object.id
    end

    def to_s
      "<Edurange::Instance name:#{@name} ami_id: #{@ami_id} ip: #{@ip_address} key: #{@key_pair} running: #{@running} instance_id: #{@instance_id}>"
    end

    def sleep_until_configurable
      loop do
        begin
          Timeout::timeout(5) do
            begin
              s = TCPSocket.new(@elastic_ip.ip_address, 22)
              s.close
              return
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            end
          end
        rescue Timeout::Error
        end
      end
    end
    def sleep_until_running
      info "Waiting for instance to spin up (approx 40 seconds)"
      sleep 10
      sleep 5 while @aws_object.status == :pending
    end
  end
end
