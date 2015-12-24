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

  def user_add(users)
  	if not users.respond_to? "each"
		users = [users]
	end

  	student_group_all = self.user.student_groups.find_by_name("All")
	student_group_users = []

	users.each do |user|
		if not student_group_all.users.find(user.id)
			errors.add(:user, "#{user.name} not found")
			return false
		end

		sgu = self.student_group_users.new(user_id: user.id)
		sgu.save
		student_group_users.push(sgu)
	end

  	return student_group_users
  end

end
