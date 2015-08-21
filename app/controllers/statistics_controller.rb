class StatisticsController < ApplicationController
  before_action :authenticate_admin_or_instructor

  def index
    # view for all statistics
    @statistics = []
    if @user.is_admin?
      @statistics = Statistic.all
    else
      @statistics = Statistic.where(user_id: current_user.id)
    end
  end

  # GET /statistic/1
  def show
    # grab statistics data for detailed view
    @statistic = Statistic.find(params[:id])
    @bash_analytics = @statistic.bash_analytics
  end

  def destroyme
    statistic = Statistic.find(params[:id])
    statistic.destroy
    if statistic.destroy
        respond_to do |format|
          format.js { render js: "window.location.pathname='/statistics'" }
        end
    #else
    #    respond_to do |format|
    #      format.js { render 'statistics/js/statistic/statistic_delete.js.erb', :layout => false }
    #    end
    end
  end

  def download_all
  end


  # download statistic data
  def download
    # save statistic as pdf
    statistic = Statistic.find(params[:id])
    File.open('')
    send_file(
      "#{Rails.root}/public/statistics/#{User.name}_statistic_#{statistic.id}.pdf",
      filename: "statistic.pdf",
      type: "application/pdf"
    )
  end

end
