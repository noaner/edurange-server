class Instance < ActiveRecord::Base
  include Provider
  include Aws

  validates_presence_of :name, :os, :subnet
  belongs_to :subnet

  has_many :instance_groups, dependent: :destroy
  has_many :instance_roles, dependent: :destroy
  has_many :groups, through: :instance_groups, dependent: :destroy
  has_many :roles, through: :instance_roles, dependent: :destroy
  has_one :user, through: :subnet
  has_one :scenario, through: :subnet

  before_create :ensure_has_ip
  validates :name, presence: true, uniqueness: { scope: :subnet, message: "Name taken" } 
  validates :ip_address, presence: true
  validate :ip_address_validate, :internet_accessible_validate, :validate_stopped

  after_destroy :update_scenario_modified
  before_destroy :validate_stopped

  def validate_stopped
    if not self.stopped?
      errors.add(:running, "can not modify while scenario is booted")
      return false
    end
    if self.scenario.modifiable?
      self.scenario.update_attribute(:modified, true)
    end
    true
  end

  def update_scenario_modified
    if self.scenario.modifiable?
      self.scenario.update_attribute(:modified, true)
    end
    true
  end

  def role_add(role_name)
    if not self.stopped?
      errors.add(:running, 'instance must be stopped to add role')
      return false
    end

    self.roles.each do |r|
      if r.name == role_name
        self.errors.add(:role_name, "Instance already has #{role_name}")
        return false
      end
    end

    if not role = self.scenario.roles.find_by_name(role_name)
      self.errors.add(:role_name, "Role does not exist")
      return false
    end
    ir = self.instance_roles.new(role_id: role.id)
    ir.save
    update_scenario_modified
    return ir
  end

  def ip_address_validate

    ip = IPAddress.valid_ipv4?(self.ip_address)
    if not ip
      errors.add(:ip_address, "IP Address is not valid")
      return
    end

    if not NetAddr::CIDR.create(self.subnet.cidr_block).cmp(self.ip_address)
      errors.add(:ip_address, "IP Address is not within instances subnet #{self.subnet.name} #{self.subnet.cidr_block}")
      return
    end

    self.subnet.instances.each do |instance|
      next if self == instance
      if self.ip_address == instance.ip_address
        errors.add(:ip_address, "IP Address is taken")
      end
    end 

  end

  def internet_accessible_validate
    if self.internet_accessible and not self.subnet.internet_accessible
      errors.add(:internet_accessible, "Instances subnet must also be internet accessible")
    end
  end

  def bootable?
    return (self.stopped? and self.subnet.booted?) 
  end

  def unbootable?
    return (self.booted? or self.boot_failed? or self.unboot_failed?)
  end

  def generate_cookbooker

    # template = File.read(Settings.app_path + "lib/templates/cookbook_template_new.rb.erb")
    # template = Erubis::Eruby.new(template)
    cookbook = "# Instance cookbook\n"

    self.roles.each do |role|
        role.recipes.each do |recipe|
          fname = Settings.app_path + "scenarios/recipes/" + recipe + ".rb.erb"
          if File.file?(fname)
            cookbook += Erubis::Eruby.new(File.read(fname)).result + "\n"
          end
        end
      end

      cookbook
  end

  def scenario
    return self.subnet.cloud.scenario
  end

  def owner?(id)
    return self.subnet.cloud.scenario.user_id == id
  end

  def status_check
    puts "\nstatus check\n"
    if self.driver_id
      if AWS::EC2.new.instances[self.driver_id].exists?
        # check if it is running
      else
        self.driver_id = nil
        self.set_stopped
        self.save
      end
    end
  end

  def get_bash_history
    return "" if (!self.bash_history_page or (self.bash_history_page == ""))

    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      if bucket.objects[self.aws_instance_bash_history_page_name].exists?
        bash_history =  bucket.objects[self.aws_instance_bash_history_page_name].read()
        return bash_history == nil ? "" : bash_history
      end
    rescue
      return "error getting bash history"
    end

    return ""
  end

  def get_exit_status
    return "" if (!self.exit_status_page or (self.exit_status_page == ""))

    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      if bucket.objects[self.aws_instance_exit_status_page_name].exists?
        exit_status =  bucket.objects[self.aws_instance_exit_status_page_name].read()
        return exit_status == nil ? "" : exit_status
      end
    rescue
      return "error getting exit status"
    end

    return ""
  end

  def get_script_log
    return "" if (!self.script_log_page or (self.script_log_page == ""))

    begin
      s3 = AWS::S3.new
      bucket = s3.buckets[Settings.bucket_name]
      if bucket.objects[self.aws_instance_script_log_page_name].exists?
        script_log =  bucket.objects[self.aws_instance_script_log_page_name].read()
        return script_log == nil ? "" : script_log
      end
    rescue
      return "error getting script log"
    end

    return ""
  end

  def get_chef_error
    return "" if !self.bash_history_page
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name]
    if bucket.objects[self.aws_instance_com_page_name].exists?
      chef_err =  bucket.objects[self.aws_instance_com_page_name].read()
      return chef_err == nil ? "" : chef_err
    end
    return ""
  end

  def initialized?
    return "-" if !self.com_page

    begin
      com_page = AWS::S3.new.buckets[Settings.bucket_name].objects[self.aws_instance_com_page_name]
      if com_page.exists?
        text = com_page.read()
        status = text.split("\n")[0]
        if status == "error"
          return "chef script error"
        elsif status == "finished"
          return "true"
        end
      end
    rescue AWS::S3::Errors::NoSuchKey
      return false
    end
    "initializing"
  end

  def port_open?(ip, port)
    begin
      Timeout::timeout(1) do 
        begin
          s = TCPSocket.open(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          return false
        end
      end
    rescue Timeout::Error
    end
    return false
  end

  def ssh_ready?
    if ip = self.aws_instance_public_ip
      if (self.port_open?(ip, 22))
        return true
      end
    end
    return false
  end

  def ensure_has_ip
    if self.ip_address.blank?
      return false # TODO set this to a valid IP in subnet cidr
    end
    true
  end

  def s3_name_prefix
    scenario = self.subnet.cloud.scenario
    return scenario.user.name + scenario.name + scenario.id.to_s + scenario.uuid
  end

  def add_progress(val)
    # debug "Adding progress to instance!"
    # PrivatePub.publish_to "/scenarios/#{self.subnet.cloud.scenario.id}", instance_progress: val
  end
  
  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attribute(:log, log + message + "\n")
  end

  def generate_init
    begin
      # Returns the bash code to initialize an instance with chef-solo
      init = ""
      os_bootstrap_path = "#{Settings.app_path}scenarios/bootstrap/os_#{self.os.filename_safe}.sh.erb"
      if File.exists? os_bootstrap_path
        init += Erubis::Eruby.new(File.read(os_bootstrap_path)).result(instance: self) + "\n"
      end

      init += Erubis::Eruby.new(File.read(Settings.app_path + "scenarios/bootstrap/chef.sh.erb")).result(instance: self) + "\n"
      init += Erubis::Eruby.new(File.read(Settings.app_path + "scenarios/bootstrap/sshd_password_login.sh.erb")).result(instance: self) + "\n"

      # Erubis::Eruby.new(File.read(Settings.app_path + "scenarios/recipes/templates/bootstrap.sh.erb")).result(instance: self) + "\n"
      init
    rescue
      raise
      return
    end
  end

  def generate_cookbook
    begin
      # Find out if this is a global or custom recipe
      scenario_path = "#{Settings.app_path}scenarios/user/#{self.scenario.user.name.filename_safe}/#{self.scenario.name.filename_safe}"
      scenario_path = "#{Settings.app_path}scenarios/local/#{self.scenario.name.filename_safe}" if not File.exists? scenario_path

      # This recipe sets up packages and users and is run for every instance
      cookbook = Erubis::Eruby.new(File.read("#{Settings.app_path}scenarios/recipes/templates/packages_and_users.rb.erb")).result(instance: self) + "\n"

      self.roles.each do |role|
        role.recipes.each do |recipe|
          if recipe.custom
            cookbook += recipe.text + "\n"
          else
            cookbook += Erubis::Eruby.new(recipe.text).result(instance: self) + "\n"
          end
        end
      end

      # This recipe signals the com page and also gets the bash histories
      cookbook += Erubis::Eruby.new(File.read("#{Settings.app_path}scenarios/recipes/templates/com_page_and_bash_histories.rb.erb")).result(instance: self) + "\n"
      # This recipe changes /etc/bash.bashrc so that the bash history is written to file with every command
      cookbook += Erubis::Eruby.new(File.read("#{Settings.app_path}scenarios/recipes/templates/write_bash_histories.rb.erb")).result(instance: self) + "\n"
      
      cookbook
    rescue
      raise
      return
    end
  end

  # Handy user methods
  def administrators
    groups = self.instance_groups.select {|instance_group| instance_group.administrator }.map {|instance_group| instance_group.group}
    users = groups.inject([]) {|users, group| users.concat(group.players) }
  end

  def users
    groups = self.instance_groups.select {|instance_group| !instance_group.administrator }.map {|instance_group| instance_group.group}
    users = groups.inject([]) {|users, group| users.concat(group.players) }
  end

  def add_administrator(group)
    InstanceGroup.create(group: group, instance: self, administrator: true)
  end

  def add_user(group)
    InstanceGroup.create(group: group, instance: self, administrator: false)
  end

end
