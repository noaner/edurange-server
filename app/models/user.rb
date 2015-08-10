class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  enum role: [:user, :vip, :admin, :instructor, :student]
  # attr_accessor :registration_code
  after_initialize :set_defaults, :if => :new_record?
  validates :email, uniqueness: true
  validates :name, presence: true
  validate :validate_name, :validate_running
  has_many :student_groups
  has_many :scenarios
  has_many :student_group_users, dependent: :destroy

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
    if self.scenarios.select{ |s| not s.stopped? }.size > 0
      errors.add(:running, "can not modify while a scenario is running")
      return false
    end
    true
  end

  def owns?(obj)
    return true if self.is_admin?
    cl = obj.class
    arr = [Cloud, Group, Instance, Scenario, StudentGroup, Subnet, InstanceRole, InstanceGroup, Role, RoleRecipe, Recipe]
    if arr.include? cl
      return obj.user == self
    elsif cl == Player
      return obj.group.user == self
    elsif cl == StudentGroupUser
      return obj.student_group.user == self
    end
  end

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
    if not self.registration_code
      self.update(registration_code: SecureRandom.hex[0..7])
    end
    if not File.exists? "#{Settings.app_path}scenarios/user/#{self.id}"
      FileUtils.mkdir "#{Settings.app_path}scenarios/user/#{self.id}"
    end
    if not self.student_groups.find_by_name("All")
      sg = self.student_groups.new(name: "All")
      sg.save
    end
    self.update(role: :instructor)
  end

  def set_student_role
    self.update_attribute :role, :student
  end

  def set_admin_role
    if not self.registration_code
      self.update(registration_code: SecureRandom.hex[0..7])
    end
    if not File.exists? "#{Settings.app_path}scenarios/user/#{self.id}"
      FileUtils.mkdir "#{Settings.app_path}scenarios/user/#{self.id}"
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

end
