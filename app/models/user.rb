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
  has_many :student_groups

  def owns?(obj)
    return true if self.is_admin?
    cl = obj.class
    if cl == Cloud or cl == Group or cl == Instance or cl == Scenario or cl == StudentGroup or cl == Subnet
      return obj.user == self
    elsif cl == Player
      return obj.group.user == self
    end
  end

  def set_defaults
    self.role ||= :student
    FileUtils.mkdir "#{Settings.app_path}scenarios/user/#{self.name.filename_safe}"
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
    self.update_attribute :role, :instructor
  end

  def set_student_role
    self.update_attribute :role, :student
  end

  def set_admin_role
    self.update_attribute :role, :admin
  end

  def email_credentials(password)
    UserMailer.email_credentials(self, password).deliver
  end

end
