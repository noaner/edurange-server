class InstructorController < ApplicationController
  before_action :authenticate_instructor

  def index
    
  end

  def student_group_new
    @user = User.find(current_user.id)

    if @user.student_groups.find_by_name(params[:name])
      redirect_to '/instructor', notice: "Student Group already exists."
    else
      student_group = @user.student_groups.new(name: params[:name])
      student_group.save
      redirect_to '/instructor', notice: "Student Group created."
    end
  end

  def student_group_assign
    params[:selects].each do |a|
      if a[1] != ''
        if !@user.student_groups.find_by_name(a[1]).student_group_users.find_by_user_id(a[0])
          sgu = @user.student_groups.find_by_name(a[1]).student_group_users.new(user_id: a[0])
          sgu.save
        end
      end
    end
    redirect_to '/instructor', notice: "Student(s) assigned to Student Group"
  end

  def student_group_remove
    StudentGroupUser.find(params[:student_group_user]).delete
    redirect_to '/instructor', notice: "Student Removed from Student Group"
  end

end
