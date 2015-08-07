class StatisticsController < ApplicationController
  before_action :authenticate_admin_or_instructor

  def index
    @statistics = []
    if @user.is_admin?
      @statistics = Statistic.all
    else
      @statistics = Statistic.where(user_id: current_user.id)
    end
  end

  def show
    # detail view of statistic
    @statistic = Statistic.find(params[:id])
    @bash_analytics = @statistic.bash_analytics
  end

  def delete
  end

  #Download statistic data
  def download
  end  

end
