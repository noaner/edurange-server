class Instance < ActiveRecord::Base
  enum status: [:stopped, :booting, :booted]
  validates_presence_of :name, :os, :subnet
  belongs_to :subnet

  has_many :instance_groups, dependent: :delete_all
  has_many :instance_roles, dependent: :delete_all
  has_many :groups, through: :instance_groups
  has_many :roles, through: :instance_roles
  
  before_create :ensure_has_ip
  validate :ip_address_must_be_within_subnet
  
  def ensure_has_ip
    if self.ip_address.blank?
      return false # TODO set this to a valid IP in subnet cidr
    end
    true
  end

  def ip_address_must_be_within_subnet
    # TODO fix
    true
  end
  def boot
    if self.stopped?
      # delayed_job, 5.times sleep 10 sec, print to /scenarios/#{1}
      debug "Booting instance..."
      self.status = "booting"
      self.save!
      
      # Boot
      self.provider_boot
      self.status = "booted"
      self.save!
    end
  end
  def provider_boot
    self.send("#{Settings.driver}_boot".to_sym)
  end
  def upload_cookbook(cookbook_text)
    return self.send("#{Settings.driver}_upload_cookbook".to_sym, cookbook_text)
  end
  def aws_upload_cookbook(cookbook_text)
    s3 = AWS::S3.new
    bucket = s3.buckets['edurange']
    unless bucket.exists?
      s3.buckets.create('edurange')
    end
    uuid = `uuidgen`
    bucket.objects[uuid].write(cookbook_text)
    cookbook_url = bucket.objects[uuid].url_for(:read, expires: 1000.minutes).to_s # 1000 minutes
    self.update_attributes(cookbook_url: cookbook_url)
    return cookbook_url
  end
  def public_ip
    self.send("#{Settings.driver}_public_ip".to_sym)
  end
  def aws_public_ip
    return false unless self.driver_id
    return false unless self.internet_accessible
    @public_ip ||= self.driver_object.public_ip_address
  end
  def aws_boot
    debug "Called aws_boot in instance!"
    debug "AWS_Driver::provider_boot - instance"
    instance_template = InstanceTemplate.new(self)
    debug "AWS_Driver::InstanceTemplate.new"
    cookbook_text = instance_template.generate_cookbook
    debug "AWS_Driver::instance_template.generate_cookbook"
    self.cookbook_url = self.upload_cookbook(cookbook_text)
    debug "AWS_Driver::self.upload_cookbook"
    cloud_init = instance_template.generate_cloud_init(self.cookbook_url)
    debug "AWS_Driver::self.generate cloud init"
    debug self.cookbook_url

    sleep 2 until self.subnet.booted?
    self.driver_id = AWS::EC2::InstanceCollection.new.create(
                                                             image_id: self.ami_id, # ami_id string of os image
                                                             private_ip_address: self.ip_address, # ip string
                                                             key_name: Settings.ec2_key, # keypair string
                                                             user_data: cloud_init, # startup data
                                                             subnet: self.subnet.driver_id).id # subnet id for where this instance goes

    # Get an EC2 client object to set the instance tags
    ec2 = AWS::EC2.new
    ec2.client.create_tags(:resources => [self.driver_id], :tags => [
                                                                     { :key => 'Name', :value => "#{self.subnet.cloud.scenario.name} - #{self.name}" }
                                                                    ])
    self.save
    debug self.inspect

    if self.internet_accessible
      run_when_booted do
        eip = AWS::EC2::ElasticIpCollection.new.create(vpc: true)
        debug "AWS_Driver:: Allocated EIP #{eip}"
        self.driver_object.associate_elastic_ip eip
        self.driver_object.network_interfaces.first.source_dest_check = false # Set first NIC (assumption) to not check source/dest. Required to accept other machines' packets
      end
    end
    add_progress
  end
  def driver_object
    AWS::EC2::InstanceCollection.new[self.driver_id]
  end
  def provider_check_status
    self.send("#{Settings.driver}_check_status".to_sym)
  end
  def aws_check_status
    if self.driver_object.status == :running
      self.status = "booted"
      self.save!
    end
  end
  def nat?
    @internet_accessible
  end
  def ami_id
    if self.os == 'ubuntu'
      'ami-31727d58' # Private ubuntu image with chef and deps, updates etc.
    elsif self.os == 'nat'
      'ami-51727d38' # Private NAT image with chef and deps, updates etc.
    end
  end
  def run_when_booted
    until self.booted?
      self.reload
      sleep 2
      provider_check_status
    end
    yield
  end
  def add_progress
    debug "Adding progress to instance!"
    PrivatePub.publish_to "/scenarios/#{self.subnet.cloud.scenario.id}", instance_progress: 1
  end
  def debug(message)
    log = self.subnet.cloud.scenario.log
    self.subnet.cloud.scenario.update_attributes(log: log + message + "\n")
    PrivatePub.publish_to "/scenarios/#{self.subnet.cloud.scenario.id}", log_message: message
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
