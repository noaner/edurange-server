class StudentGroup < ActiveRecord::Base
  has_many  :players

  def user
    return User.find(self.student_id)
  end

end
