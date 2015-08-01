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
  end

  def delete
  end

  #Download statistic data
  def download
  end  

end
