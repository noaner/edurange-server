class StudentController < ApplicationController
  # layout 'student'
  before_action :authenticate_student

  def index
    @scenarios = []
    @instances = []
    @login_info = {}
    Player.where(:user_id => current_user.id).each do |player|
      if group = Group.where(:id => player.group_id).first
        @scenarios << Scenario.where(:id => group.scenario_id).first
        InstanceGroup.where(:group_id => group.id).each do |instance_group|
          @instances << Instance.where(:id => instance_group.instance_id).first
        end
      end
      @login_info[:login] = player.login
      @login_info[:password] = player.password
    end
  end
end
