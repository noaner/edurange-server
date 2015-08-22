class StatisticsController < ApplicationController
  before_action :authenticate_admin_or_instructor
  require 'rubygems'
  require 'zip'
  require 'tempfile'

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
    end
  end

  def download_all
    @statistics = []
    if @user.is_admin?
      @statistics = Statistic.all
    else
      @statistics = Statistic.where(user_id: current_user.id)
    end

    folder = "#{Rails.root}/public/statistics/"
    input_filepaths = []
    input_filenames = []
    @statistics.each do |statistic|
      file_path = "#{Rails.root}/public/statistics/#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
      file_name = "#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
      if File.exist?(file_path)
        input_filepaths.push(file_path)
        input_filenames.push(file_name)
      end
    end
    #create a temporary zip file
    temp_file = Tempfile.new("statistics.zip")
    begin
      #Initialize the temp file as a zip file
      Zip::OutputStream.open(temp_file) { |zos| }

      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
        input_filenames.each do |filename|
          zipfile.add(filename, folder + filename)
        end
      end
      #Read the binary data from the file
      zip_data = File.read(temp_file.path)
      send_data(zip_data, :type => 'application/zip', :filename => "statistic_data.zip")
    ensure
      #close and delete the temp file
      temp_file.close
      temp_file.unlink
    end
  end


  # download statistic data
  def download
    # save statistic as pdf
    statistic = Statistic.find(params[:id])
    bash_analytics = ""
    statistic.bash_analytics.each do |analytic| 
      bash_analytics = bash_analytics + "#{analytic}" + "\n"
    end
    file_text = "Scenario #{statistic.scenario_name} created at #{statistic.scenario_created_at}\nStatistic #{statistic.id} created at #{statistic.created_at}\n\nBash Histories: \n \n#{statistic.bash_histories} \nBash Analytics: \n#{bash_analytics}"
    file_path = "#{Rails.root}/public/statistics/#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
    file_name = "#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
    if File.exist?(file_path)
      send_file(file_path, filename: file_name, type: "application/txt")
    else
      send_data(file_text, filename: file_name, type: "application/txt")
    end
  end
end
