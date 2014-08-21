class InstructorController < ApplicationController
  before_action :authenticate_instructor

  def index
    @student_groups = StudentGroup.where :student_id => current_user.id
    @student_groups_size = {}
    @student_groups.each do |student_group|
      size = StudentGroup.where(:name => student_group.name).size - 1
      @student_groups_size[student_group.name]= size
    end
  end

  def groups_add
    group = StudentGroup.where(
                              :instructor_id => current_user.id, 
                              :name => params[:name]
                              )
    if group.blank?
      StudentGroup.create(
                          :instructor_id => current_user.id, 
                          :name => params[:name], 
                          :student_id => current_user.id
                          )
    else
      message = "Group already exists"
    end
    redirect_to instructor_groups_path :message => message
  end

  def group_delete
    group_name = params[:group_name]
    StudentGroup.where(
                      :instructor_id => current_user.id, 
                      :name => group_name
                      ).destroy_all
    redirect_to instructor_groups_path
  end

  def group_add_to
    user = User.find_by_email params[:email]
    if user
      if user.is_student?
        record = StudentGroup.where(
                                    :instructor_id => current_user.id, 
                                    :name => params[:group_name], 
                                    :student_id => user.id
                                    )
        if record.blank?
          StudentGroup.create(
                              :instructor_id => current_user.id, 
                              :name => params[:group_name], 
                              :student_id => user.id
                              )
        else
          message = "student already in group"
        end
      end
    else
      message = "student not found"
    end
    redirect_to instructor_groups_path :message => message
  end

  def group_remove_from
    user = User.find_by_email params[:email]
    if user
      StudentGroup.where(
                        :instructor_id => current_user.id, 
                        :name => params[:group_name],
                        :student_id => user.id
                        ).destroy_all
    end
    redirect_to instructor_groups_path
  end

end
