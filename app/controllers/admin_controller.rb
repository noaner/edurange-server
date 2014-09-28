class AdminController < ApplicationController
  before_action :authenticate_admin

  def index
    @instructors = User.where 'role' => 3
  end

  def instructor_add
    @email = params[:email]
    if user = User.find_by_email(@email)
      if user.is_instructor?
        @error_message = "User is already an instructor"
      else
        user.set_instructor_role
        user.update_attribute :registration_code, SecureRandom.base64(6)
        user.student_groups.new(name: "All")
        user.save
      end
    else
      flash[:notice] = "No user found with that email"
    end
    redirect_to '/admin'
  end

  def instructor_remove
    if user = User.find(params[:id])
      user.set_student_role
    end
    redirect_to '/admin'
  end

end