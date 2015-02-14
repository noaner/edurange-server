class StudentGroup < ActiveRecord::Base
  belongs_to :user
  has_many   :student_group_users, dependent: :destroy
end
