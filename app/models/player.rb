require 'unix_crypt'
class Player < ActiveRecord::Base
  belongs_to :group
  validates_presence_of :group
  belongs_to :student_group
  belongs_to :user

  validates :login, presence: true, uniqueness: { scope: :group, message: "name already taken" }
  validates :password, presence: true

   def password_hash
     UnixCrypt::SHA512.build(self.password)
   end
end
