class StudentGroup < ActiveRecord::Base
  belongs_to :user
  has_many   :student_group_users, dependent: :destroy
  has_many :users, through: :student_group_users

  validates :name, presence: true, uniqueness: { scope: :user, message: "Name taken" } 

  # before_destroy :check_if_all

  # def check_if_all
  # 	if self.name == "All"
  # 		errors.add(:name, "can not delete Student Group All")
  # 		return false
  # 	end
  # 	true
  # end

  def user_add(user)
  	student_group_all = self.user.student_groups.find_by_name("All")
  	if not student_group_all.users.find(user.id)
  		errors.add(:user, "user not found")
  		return false
  	end

  	sgu = self.student_group_users.new(user_id: user.id)
    sgu.save
  	return sgu
  end

end
