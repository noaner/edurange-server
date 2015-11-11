class StatisticsController < ApplicationController
  before_action :authenticate_admin_or_instructor
  require 'rubygems'
  require 'zip'
  require 'tempfile'
  require 'json'

  def index
    # view for all statistics
    @statistics = []
    if @user.is_admin?
      @statistics = Statistic.all
    else
      @statistics = Statistic.where(user_id: current_user.id)
    end
  end

  # GET /statistic/<id>
  def show
    # find the statistic by id
    @statistic = Statistic.find(params[:id])
    # grab the analytics data
    @bash_analytics = @statistic.bash_analytics
    # grab usernames & make available in UI
    @users = @bash_analytics.keys
    @statistic_id = @statistic.id
  end
  
  # GET /statistic/<id>/destroyme
  def destroyme
    statistic = Statistic.find(params[:id])
    statistic.destroy
    if statistic.destroy
      respond_to do |format|
        format.js { render js: "window.location.pathname='/statistics'" }
      end
    end
  end


  # GET /statistic/1/download_all
  def download_all
    @statistics = []
    if @user.is_admin?
      @statistics = Statistic.all
    else
      @statistics = Statistic.where(user_id: current_user.id)
    end

    folder = "#{Rails.root}/data/statistics/"
    input_filepaths = []
    input_filenames = []
    @statistics.each do |statistic|
      # add bash histories
      file_path = "#{Rails.root}/data/statistics/#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
      file_name = "#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
      if File.exist?(file_path)
        input_filepaths.push(file_path)
        input_filenames.push(file_name)
      end
      # add exit statuses
      exit_status_path = "#{Rails.root}/data/statistics/#{statistic.id}_Exit_Status_#{statistic.scenario_name}.txt"
      exit_status_name = "#{statistic.id}_Exit_Status_#{statistic.scenario_name}.txt"
      if File.exist?(exit_status_path)
        input_filepaths.push(exit_status_path)
        input_filenames.push(exit_status_name)
      end
      # add script logs
      script_log_path = "#{Rails.root}/data/statistics/#{statistic.id}_Script_Log_#{statistic.scenario_name}.txt"
      script_log_name = "#{statistic.id}_Script_Log_#{statistic.scenario_name}.txt"
      if File.exist?(script_log_path)
        input_filepaths.push(script_log_path)
        input_filenames.push(script_log_name)
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

  
  # GET /statistic/<id>/download
  # download statistic data
  def download_bash_history
    # save statistic bash history
    statistic = Statistic.find(params[:id])
    
    # Download bash histories and analytics in a file
    bash_analytics = ""
    statistic.bash_analytics.each do |analytic| 
      bash_analytics = bash_analytics + "#{analytic}" + "\n"
    end
    file_text = "Scenario #{statistic.scenario_name} created at #{statistic.scenario_created_at}\nStatistic #{statistic.id} created at #{statistic.created_at}\n\nBash Histories: \n \n#{statistic.bash_histories} \nBash Analytics: \n#{bash_analytics}"
    file_path = "#{Rails.root}/data/statistics/#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
    file_name = "#{statistic.id}_Statistic_#{statistic.scenario_name}.txt"
    if File.exist?(file_path)
      send_file(file_path, filename: file_name, type: "application/txt")
    else
      send_data(file_text, filename: file_name, type: "application/txt")
    end
  end

def download_exit_status
    # Download exit statuses
    statistic = Statistic.find(params[:id])

    exit_status_text = "Scenario #{statistic.scenario_name} created at #{statistic.scenario_created_at}\nStatistic #{statistic.id} created at #{statistic.created_at}\n\nExit Status Data: \n \n#{statistic.exit_status} \n"
    exit_status_path = "#{Rails.root}/data/statistics/#{statistic.id}_Exit_Status_#{statistic.scenario_name}.txt"
    exit_status_name = "#{statistic.id}_Exit_Status_#{statistic.scenario_name}.txt"
    if File.exist?(exit_status_path)
      send_file(exit_status_path, filename: exit_status_name, type: "application/txt")
    else
      send_data(exit_status_text, filename: exit_status_name, type: "application/txt")
    end
  end

def download_script_log
    # Download script logs
    statistic = Statistic.find(params[:id])

    script_log_text = "Scenario #{statistic.scenario_name} created at #{statistic.scenario_created_at}\nStatistic #{statistic.id} created at #{statistic.created_at}\n\nScript Log Data: \n \n#{statistic.script_log} \n"
    script_log_path = "#{Rails.root}/data/statistics/#{statistic.id}_Script_Log_#{statistic.scenario_name}.txt"
    script_log_name = "#{statistic.id}_Script_Log_#{statistic.scenario_name}.txt"
    if File.exist?(script_log_path)
      send_file(script_log_path, filename: script_log_name, type: "application/txt")
    else
      send_data(script_log_text, filename: script_log_name, type: "application/txt")
    end   
  end

  # method called via AJAX request, sends javascript response after performing analytics  
  def generate_analytics
    # parameters passed in via query string, see comment above
    statistic = Statistic.find(params[:id]) # yank statistic entry
    user = params[:user]  # array of usernames
    # start_time = params[:start_time]  # start of time window (as string)
    # end_time = params[:end_time]  # end of time window (also as string)
    # find relevant commands based on query params above
    if statistic.bash_analytics.keys.include?(user) && statistic.bash_analytics[user] != {}
      times = statistic.bash_analytics[user].keys.sort
      start = times[0]
      end_ = times[-1]
      commands = statistic.grab_relevant_commands(user, start, end_)
      # perform analytics on the comands & put into serializable form
      @analytics = statistic.perform_analytics(commands).to_json
      respond_to do |format|
        format.js{ render js: "new Chartkick.ColumnChart('chart', #{@analytics});" }
      end
    else
      respond_to do |format|
        format.js{ render js: "alert('User not in scenario.');"}
      end
    end
  end

end
