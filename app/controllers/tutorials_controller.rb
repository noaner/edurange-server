class TutorialsController < ApplicationController
  before_action :authenticate_admin_or_instructor
  before_action :set_user

  def index
      #@tutorials = Tutorial.all
  end

  def making_scenarios
  end

  def instructor_manual
    send_file("#{Rails.root}/app/views/tutorials/EDURange_for_faculty.pdf", :disposition => 'inline',:type => 'application/pdf')
  end

  def student_manual
    send_file("#{Rails.root}/app/views/tutorials/EDURange_for_students.pdf", :disposition => 'inline',:type => 'application/pdf')
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(current_user.id)
    end

end
