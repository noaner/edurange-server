class InstructorController < ApplicationController
  before_action :authenticate_instructor
  before_action :set_student_group, only: [:student_group_destroy]

  def index
    @players = Player.where(user_id: current_user.id)
  end

  def student_group_create
    @user = User.find(current_user.id)
    @student_group = @user.student_groups.new(name: params[:name])
    @student_group.save

    respond_to do |format|
      format.js { render 'instructor/student_group_create.js.erb', :layout => false }
    end
  end

  def student_group_destroy
    @student_group.destroy
    respond_to do |format|
      format.js { render 'instructor/student_group_delete.js.erb', :layout => false }
    end
  end

  def student_group_user_add
    user = User.find(params[:user_id])
    @student_group_user = nil
    if @student_group = @user.student_groups.find_by_name(params[:student_group_name])
      @student_group_user = @student_group.user_add(user)
    end

    respond_to do |format|
      format.js { render 'instructor/student_group_user_add.js.erb', :layout => false }
    end
  end

  def student_group_user_remove
    @student_group_user = StudentGroupUser.find(params[:student_group_user_id])
    if @student_group_user.student_group.user == User.find(current_user.id)
      @student_group_user.destroy
    end

    respond_to do |format|
      format.js { render 'instructor/student_group_user_remove.js.erb', :layout => false }
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
