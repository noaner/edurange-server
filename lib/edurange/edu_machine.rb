module Edurange
  class EduMachine
    attr_reader :uuid, :ami_id, :key_name, :vm_size, :ip_address, :users

    EC2_UTILS_PATH = "/home/ubuntu/.ec2/bin/"

    def initialize(uuid, key_name, ami_id, vm_size="t1.micro")
      # generate uuid
      @uuid = uuid
      @instance_id = nil
      @key_name = key_name
      @vm_size = vm_size
      @ami_id = ami_id
    end
    def initial_users(users)
      @users = users
    end
    def run(command)
      # runs an ec2 command with full path.
      command = EC2_UTILS_PATH + command
      `#{command}`
    end

    def spin_up
      # Pref user-data-file for ourselves

      # Create & run instance, setting instance_id and IP to match the newly created ami
      command = "ec2-run-instances #{@ami_id} -t #{@vm_size} --region us-east-1 --key #{@key_name} --user-data-file my-user-script.sh"
      puts "Would run: #{command}"
      self.run(command)
      @instance_id = self.get_last_instance_id()
      puts "Waiting for instance #{@instance_id} to spin up..."
      sleep(40)
      self.update_ec2_info()
      self
    end

    def update_ec2_info
      command = "ec2-describe-instances | grep INSTANCE | grep '#{@instance_id}'"
      vm = self.run(command).split("\t")
      p vm
      @ip_address = vm[17] # public ip
      @hostname = vm[3] # ec2 hostname
    end

    def get_last_instance_id
      command = 'ec2-describe-instances | grep INSTANCE | tail -n 1'
      vm = self.run(command)
      return vm.split("\t")[1]
    end
  end
end
