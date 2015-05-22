class AdminController < ApplicationController
  before_action :authenticate_admin

  def index
    @instructors = User.where role: 3
    @students = User.where role: 1
  end

  def instructor_create
    name = params[:name] == '' ? nil : params[:name]
    @user = User.new(email: params[:email], name: name, organization: params[:organization])
    password = SecureRandom.hex
    @user.password = password
    @user.save

    if not @user.errors.any?
      @user.set_instructor_role
      UserMailer.email_credentials(@user, password).deliver
    end

    respond_to do |format|
      format.js { render 'admin/instructor_create.js.erb', :layout => false }
    end
  end

  # need to error messaging for this function
  def instructor_delete
    if @user = User.find(params[:id])
      @user.destroy
    end
    
    respond_to do |format|
      format.js { render 'admin/instructor_delete.js.erb', :layout => false }
    end
  end

  def student_to_instructor
    if @user = User.find_by_email(params[:email])
      if not @user.is_student?
        @user.errors.add(:email, "User is not a student")
      else
        @user.set_instructor_role
        @user.update_attribute :registration_code, SecureRandom.base64(6)
        @user.student_groups.new(name: "All")
        @user.save
      end
    end

    respond_to do |format|
      format.js { render 'admin/student_to_instructor.js.erb', :layout => false }
    end
  end

end
