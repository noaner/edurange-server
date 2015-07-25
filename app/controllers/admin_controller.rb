class AdminController < ApplicationController
  before_action :authenticate_admin
  before_action :set_student_group, only: [:student_group_destroy]

  def index
    @instructors = User.where role: 3
    @students = User.where role: 4
  end

  def instructor_create
    name = params[:name] == '' ? nil : params[:name]
    @user = User.new(email: params[:email], name: name, organization: params[:organization])
    password = SecureRandom.hex[0..15]
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

  def reset_password
    @user = User.find(params[:id])
    password = SecureRandom.hex[0..15]
    @user.password = password
    @user.save

    if not @user.errors.any?
      @user.set_instructor_role
      UserMailer.email_credentials(@user, password).deliver
    end

    respond_to do |format|
      format.js { render 'admin/reset_password.js.erb', :layout => false }
    end
  end

  def user_delete
    if @user = User.find(params[:id])
      @user.destroy
    end
    
    respond_to do |format|
      format.js { render 'admin/user_delete.js.erb', :layout => false }
    end
  end

  def student_to_instructor
    if @user = User.find(params[:id])
      if not @user.is_student?
        @user.errors.add(:email, "User is not a student")
      else
        @user.set_instructor_role
      end
    end

    respond_to do |format|
      format.js { render 'admin/student_to_instructor.js.erb', :layout => false }
    end
  end

  def instructor_to_student
    if @user = User.find(params[:id])
      if not @user.is_instructor?
        @user.errors.add(:email, "User is not a student")
      else
        @user.set_student_role
      end
    end

    respond_to do |format|
      format.js { render 'admin/instructor_to_student.js.erb', :layout => false }
    end
  end

  def student_group_create
    @user = User.find(current_user.id)
    @student_group = @user.student_groups.new(name: params[:name])
    @student_group.save

    respond_to do |format|
      format.js { render 'admin/student_group_create.js.erb', :layout => false }
    end
  end

  def student_group_destroy
    @student_group.destroy
    respond_to do |format|
      format.js { render 'admin/student_group_delete.js.erb', :layout => false }
    end
  end

  def student_group_user_add
    user = User.find(params[:user_id])
    @student_group_user = nil
    if @student_group = @user.student_groups.find_by_name(params[:student_group_name])
      @student_group_user = @student_group.user_add(user)
    end

    respond_to do |format|
      format.js { render 'admin/student_group_user_add.js.erb', :layout => false }
    end
  end

  def student_group_user_remove
    @student_group_user = StudentGroupUser.find(params[:student_group_user_id])
    if @student_group_user.student_group.user == User.find(current_user.id)
      @student_group_user.destroy
    end

    respond_to do |format|
      format.js { render 'admin/student_group_user_remove.js.erb', :layout => false }
    end
  end

  private

  def set_student_group
    @student_group = StudentGroup.find(params[:student_group_id])
    if not User.find(current_user.id).owns? @student_group
      head :ok, content_type: "text/html"
      return
    end
  end

end
