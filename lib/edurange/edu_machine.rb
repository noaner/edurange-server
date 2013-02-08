module Edurange
  class EduMachine
    attr_reader :uuid, :ami_id, :key_name, :vm_size, :ip_address


    def init(key_name, vm_size="t1.micro")
      # generate uuid
      self.uuid =
      self.instance_id = nil
      self.key_name = key_name
      self.vm_size = vm_size
    end

    def spin_up
      # Pref user-data-file for ourselves

      # Create & run instance, setting instance_id and IP to match the newly created ami
      command = "ec2-run-instances #{self.ami_id} -t #{self.vm_size} --region us-east-1 --key #{self.key_name} --user-data-file my-user-script.sh"
      # run(command)
      self.instance_id = get_last_instance_id()
      self.update_ec2_info()
    end

    def update_ec2_info
      command = "ec2-describe-instances | grep INSTANCE | grep '#{self.instance_id}'"
      vm = run(command).split("\t")
      self.ip_address = vm[17] # public ip
      self.hostname = vm[3] # ec2 hostname
    end
  end
end
