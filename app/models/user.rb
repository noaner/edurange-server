class User < ActiveRecord::Base
  include FlagShihTzu

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :trackable, :validatable
  enum role: [:user, :vip, :admin, :instructor, :student]

  has_many :student_groups, dependent: :destroy
  has_many :student_group_users, dependent: :destroy

  # relationships managed via keys
  has_many :keys, dependent: :destroy
  has_many :scenarios, through: :keys, source: :resource, source_type: Scenario

  # build can_create_* flags
  CREATES = [Scenario]

  CREATES.size.times do |i|
    has_flags (i + 1) => "can_create_#{CREATES[i].to_s.underscore}".to_sym
  end

  after_initialize :set_defaults, :if => :new_record?
  validates :email, uniqueness: true
  validates :name, presence: true
  validate :validate_name, :validate_running


  #############################################################################
  # Validations

  def validate_name
    return if not self.name
    self.name = self.name.strip
    if self.name == ""
      errors.add(:name, "can not be blank")
      return false
    elsif /\W/.match(self.name)
      errors.add(:name, "can only contain alphanumeric and underscore")
      return false
    elsif /^_*_$/.match(self.name)
      errors.add(:name, "not allowed")
      return false
    end
    true
  end

  def validate_running
    self.scenarios.reload
    if self.scenarios.any?{ |s| not s.stopped? }
      errors.add(:running, "can not modify while a scenario is running")
      return false
    end
    return true
  end


  #############################################################################
  # Capabilities

  def key_for(obj)
    keys.find { |k| k.resource == obj }
  end

  def key_for!(obj)
    # creates key if one doesn't exist
    key = key_for obj
    key = keys.create(resource: obj) if key.nil?
    return key
  end

  def owns?(obj)
    if [Scenario, Role, Recipe, Cloud, Subnet].include? obj.class
      # use keys for scenario ownership
      return can? :edit, obj.scenario
    else
      # revert to tradional model for everything else
      return true if self.is_admin?
      cl = obj.class
      arr = [Cloud, Group, Instance, StudentGroup, Subnet, InstanceRole, Scenario,
             InstanceGroup, Role, RoleRecipe, Recipe, Answer]
      if arr.include? cl
        return obj.user == self
      elsif cl == Player
        return obj.group.user == self
      elsif cl == StudentGroupUser
        return obj.student_group.user == self
      end
    end
  end

  def owns!(obj)
    self.key_for!(obj).set_all_flags(true)
  end

  def disown!(obj)
    keys.destroy_all(resource: obj)
  end

  def can?(flag, obj=nil)
    if obj.nil?
      send "can_#{flag.to_s}"
    else
      if key_for(obj)
        key_for(obj).can? flag
      else
        false
      end
    end
  end

  def can!(flag, obj=nil)
    if obj.nil?
      self.send "can_#{flag.to_s}=", true
    else
      self.key_for!(obj).can! flag
    end
  end

  def cannot!(flag, obj=nil)
    if obj.nil?
      self.send "can_#{flag.to_s}=", false
    else
      self.key_for(obj).cannot! flag
    end
  end

  def create_scenario(**opts)
    # creates a scenario and takes ownership of it
    scenario = Scenario.create(user: self, **opts)
    self.owns! scenario
    return scenario
  end

  def add_resource(obj)
    self.keys.create(resource: obj)
  end


  #############################################################################
  # Roles

  def set_defaults
    self.role ||= :student
  end

  def is_admin?
    return self.role == 'admin'
  end

  def is_instructor?
    return self.role == 'instructor'
  end

  def is_student?
    return self.role == 'student'
  end

  def set_instructor_role
    self.can! :create_scenario
    if not self.registration_code
      self.update(registration_code: SecureRandom.hex[0..7])
    end
    if not File.exists? "#{Rails.root}/scenarios/custom/#{self.id}"
      FileUtils.mkdir "#{Rails.root}/scenarios/custom/#{self.id}"
    end
    if not self.student_groups.find_by_name("All")
      sg = self.student_groups.new(name: "All")
      sg.save
    end
    self.update(role: :instructor)
  end

  def set_student_role
    self.cannot! :create_scenario
    if not self.validate_running
      return
    end
    self.student_groups.destroy_all
    self.update_attribute :role, :student
  end

  def set_admin_role
    self.can! :create_scenario
    if not self.registration_code
      self.update(registration_code: SecureRandom.hex[0..7])
    end
    if not File.exists? "#{Rails.root}/scenarios/custom"
      FileUtils.mkdir "#{Rails.root}/scenarios/custom"
    end
    if not File.exists? "#{Rails.root}/scenarios/custom/#{self.id}"
      FileUtils.mkdir "#{Rails.root}/scenarios/custom/#{self.id}"
    end
    if not self.student_groups.find_by_name("All")
      sg = self.student_groups.new(name: "All")
      sg.save
    end
    self.update(role: :admin)
  end

  def email_credentials(password)
    UserMailer.email_credentials(self, password).deliver_now
  end

  def student_to_instructor
    puts self.student_group_users.destroy_all
    self.student_group_users.destroy
    self.set_instructor_role
  end

  def student_add_to_all(student)
    if sg = self.student_groups.find_by_name("All")
      sgu = sg.student_group_users.new(user_id: student.id)
      sgu.save
    end
    return sg, sgu
  end

  def instructor_to_student(user)
    if user and (user.is_admin? or user.is_instructor?)
      if sg = user.student_groups.find_by_name("All")
        sgu = sg.student_group_users.new(user_id: self.id)
        sgu.save
      end
    end
    self.set_student_role
    return sg, sgu
  end
end
