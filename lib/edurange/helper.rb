module Edurange
  class Helper
    def self.startup_script
      File.open('my-user-script.sh', 'rb').read
    end
    # Creates Bash lines to create user account and set password file or password given users
    #
    # ==== Attributes
    #
    # * +users+ - Takes parsed users
    # 
    def self.users_to_bash(users)
      shell = ""
      users.each do |user|
        if user['password']
          shell += "\n"
          shell += "sudo useradd -m #{user['login']} -s /bin/bash\n"
          # Regex for alphanum only in password input
          shell += "echo #{user['login']}:#{user['password'].gsub(/[^a-zA-Z0-9]/, "")} | chpasswd\n" 
      # TODO - do something
        elsif user['pass_file']
          shell += "\n"
          shell += "sudo useradd -m #{user['login']} -s /bin/bash\n"
          shell += "sudo mkdir -p /home/#{user['login']}/.ssh\n"
          shell += "echo '#{user['pass_file']}' >> /home/#{user['login']}/.ssh/authorized_keys\n"
        end
      end
      shell
    end

  end
end

