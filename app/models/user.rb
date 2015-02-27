class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  enum role: [:user, :vip, :admin, :instructor, :student]
  # attr_accessor :registration_code
  after_initialize :set_default_role, :if => :new_record?
  validates :email, uniqueness: true
  validates :name, presence: true

  has_many :student_groups

  def set_default_role
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
    self.update_attribute :role, :instructor
  end

  def set_student_role
    self.update_attribute :role, :student
  end

  def email_credentials(password)
    UserMailer.email_credentials(self, password).deliver
  end

end
