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

  before_create :ensure_has_ip
  validate :ip_address_must_be_within_subnet

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
    return false if !self.bash_history_page
    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name]
    if bucket.objects[self.aws_instance_bash_history_page_name].exists?
      bash_history =  bucket.objects[self.aws_instance_bash_history_page_name].read()
      return bash_history == nil ? "" : bash_history
    end
    return ""
  end

  def initialized?
    return false if !self.com_page

    s3 = AWS::S3.new
    bucket = s3.buckets[Settings.bucket_name]
    if bucket.objects[self.aws_instance_com_page_name].exists?
      return true if bucket.objects[self.aws_instance_com_page_name].read() == 'finished'
    end
    false
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
      return (self.port_open?(ip, 22) and self.initialized?)
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

  def ip_address_must_be_within_subnet
    # TODO fix
    true
  end

  def add_progress(val)
    # debug "Adding progress to instance!"
    # PrivatePub.publish_to "/scenarios/#{self.subnet.cloud.scenario.id}", instance_progress: val
  end
  
  def debug(message)
    log = self.log ? self.log : ''
    message = '' if !message
    self.update_attributes(log: log + message + "\n")
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
