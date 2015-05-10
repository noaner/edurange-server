class ScenariosController < ApplicationController
  before_action :authenticate_admin_or_instructor

  before_action :set_user, only: [:index, :show, :boot_cloud, :delete_player, :get_log, :set_scenario, :set_cloud, :set_subnet, :set_instance]

  before_action :set_scenario, only: [:show, :edit, :update, :destroyme, :status, :boot, :unboot, :boot_status, :modify_players, :modify, :add_cloud, :add_student_group_to_players]
  
  before_action :set_cloud, only: [:boot_cloud, :unboot_cloud, :delete_cloud, :modify_cloud, :add_subnet]
  
  before_action :set_subnet, only: [:boot_subnet, :unboot_subnet, :modify_subnet, :delete_subnet, :add_instance]
  
  before_action :set_instance, only: [:boot_instance, :unboot_instance, :delete_instance, :get_instance_bash_history]

  before_action :set_group, only: [:add_player, :add_student_group, :remove_student_group]


  # GET /scenarios
  # GET /scenarios.json
  def index
    @scenarios = []
    if @user.is_admin?
      @scenarios = Scenario.all
    else
      @scenarios = Scenario.where(user_id: current_user.id)
    end
  end

  def status
    # @total_booted = 0
    # @total_instances = 0

    # @scenario.clouds.each do |cloud|
    #   cloud.subnets.each do |subnet|
    #     subnet.instances.each do |instance|
    #       if instance.scoring_page.blank?
    #         next
    #       end
    #       @total_instances += 1
    #       body = Net::HTTP.get(URI(instance.scoring_page))
    #       puts "GET #{instance.scoring_page}"
    #       begin
    #         if Nokogiri.XML(body).children.first.name = 'Error'
    #         end
    #       rescue NoMethodError
    #         @total_booted += 1
    #       end
    #     end
    #   end
    # end
    respond_to do |format|
      format.html
      format.json { render json: {total: @total_instances, booted: @total_booted} }
    end
  end
  # GET /scenarios/1
  # GET /scenarios/1.json
  def show
  end

  # GET /scenarios/new
  def new
    @scenario = Scenario.new
    @templates = YmlRecord.yml_headers.map {|filename,name,desc| [name,filename,desc]}
  end

  # GET /scenarios/1/edit
  def edit
    @templates = []
  end

  # POST /scenarios
  # POST /scenarios.json
  def create
    # scrub this template input
    if template = scenario_params["template"]
      @scenario = YmlRecord.load_yml("scenarios/local/#{template}/#{template}.yml")
    else
      @scenario = Scenario.new(scenario_params)
    end

    @scenario.user_id = current_user.id
    @scenario.save!

    respond_to do |format|
      if @scenario.save
        format.html { redirect_to @scenario, notice: 'Scenario was successfully created.' }
        format.json { render :show, status: :created, location: @scenario }
      else
        format.html { render :new }
        format.json { render json: @scenario.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /scenarios/1
  # PATCH/PUT /scenarios/1.json
  def update
    respond_to do |format|
      if @scenario.update(scenario_params)
        format.html { redirect_to @scenario, notice: 'Scenario was successfully updated.' }
        format.json { render :show, status: :ok, location: @scenario }
      else
        format.html { render :edit }
        format.json { render json: @scenario.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /scenarios/1
  # DELETE /scenarios/1.json
  def destroyme
    if @scenario.booted? or @scenario.partially_booted?
      respond_to do |format|
        format.js { render 'scenarios/js/destroy_failed.js.erb', :layout => false }
      end
    else
      @scenario.destroy
      respond_to do |format|
        format.js { render js: "window.location.pathname='/scenarios'" }
        # format.js { redirect_to scenarios_url, notice: 'Scenario was successfully destroyed.' }
        # format.json { head :no_content }
      end
    end
  end

  #############################################################
  # BOOTING

  def boot
    if @scenario.stopped? or @scenario.partially_booted?
      @scenario.set_queued_boot
      @scenario.delay(queue: 'scenarios').boot(boot_dependents: true, run_asynchronously: Settings.boot_asynchronously)
      @flash_message = "Scenario #{@scenario.name} has been placed in the boot queue"
    end

    @hide_dropdown = true
    respond_to do |format|
      format.js { render 'scenarios/js/boot.js.erb', :layout => false }
    end
  end

  def unboot
    if @scenario.booted? or @scenario.partially_booted?
      @scenario.set_queued_unboot
      @scenario.delay(queue: 'scenarios').unboot(unboot_dependents: true, run_asynchronously: Settings.boot_asynchronously)
      @flash_message = "Scenario #{@scenario.name} has been placed in the unboot queue"
    end

    @hide_dropdown = true
    respond_to do |format|
      format.js { render 'scenarios/js/unboot.js.erb', :layout => false }
    end
  end

  def boot_cloud
    if @cloud.stopped?
      @cloud.set_queued_boot
      @cloud.delay(queue: 'clouds').boot
      @flash_message = "Cloud #{@cloud.name} has been placed in the boot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_cloud.js.erb', layout: false }
    end
  end

  def unboot_cloud
    if @cloud.subnets_booted?
      @cloud.errors.add(:active_subnets, "Clouds subnets must be unbooted before cloud can unboot")
    else
      @cloud.set_queued_unboot
      @cloud.delay(queue: 'clouds').unboot
      @flash_message = "Cloud #{@cloud.name} has been placed in the unboot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_cloud.js.erb',  layout: false }
    end
  end

  def boot_subnet
    if not @subnet.cloud.booted?
      @subnet.errors.add(:cloudnotbooted, "Instances Subnet must be booted first")
    else
      @subnet.set_queued_boot
      @subnet.delay(queue: 'subnets').boot
      @flash_message = "Subnet #{@subnet.name} has been placed in the boot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_subnet.js.erb', layout: false }
    end
  end

  def unboot_subnet
    if @subnet.instances_active?
      @subnet.errors.add(:instancesnotunbooted, "Subnets instances must be unbooted first")
    else
      @subnet.set_queued_unboot
      @subnet.delay(queue: 'subnets').unboot
      @flash_message = "Subnet #{@subnet.name} has been placed in the unboot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_subnet.js.erb', layout: false }
    end
  end

  def boot_instance
    if not @instance.subnet.booted?
      @instance.errors.add(:subnetnotbooted, "Instances Subnet must be booted first")
    else
      @instance.set_queued_boot
      @instance.delay(queue: 'instances').boot
      @flash_message = "Instance #{@instance.name} has been placed in the boot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_instance.js.erb', layout: false }
    end
  end

  def unboot_instance
    if @instance.driver_id
      @instance.set_queued_unboot
      @instance.delay(queue: 'instances').unboot
      @flash_message = "Instance #{@instance.name} has been placed in the unboot queue"
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_instance.js.erb', layout: false }
    end
  end

  def boot_status
    @scenario.get_status
    respond_to do |format|
      format.js { render 'scenarios/js/boot_status.js.erb', :layout => false }
    end
  end

  ###############################################################
  #  Resource Modification

  def modify
    @scenario.name = params[:name]
    @scenario.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/modify.js.erb', layout: false }
    end
  end

  def add_cloud
    @cloud = @scenario.clouds.new
    @cloud.name = params[:name]
    @cloud.cidr_block = params[:CIDR]
    @cloud.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_cloud.js.erb', layout: false }
    end
  end

  def delete_cloud
    # destroy all it's parts
    if @cloud.subnets.size > 0
      @cloud.errors.add(:has_dependents, "Cannot delete cloud because it has dependents")
    else
      @cloud.destroy
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/delete_cloud.js.erb', layout: false }
    end
  end

  def modify_cloud
    @cloud.name = params[:name]
    @cloud.cidr_block = params[:CIDR]
    @cloud.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/modify_cloud.js.erb', layout: false }
    end
  end

  def add_subnet
    # should add a new subnet based on cloud
    # @subnet = Subnet.new
    # @subnet.errors.add(:name, "FOO")
    # @subnet.errors.add(:cidr_block, "FOO")

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_subnet.js.erb', layout: false }
    end
  end

  def modify_subnet
    @subnet.name = params[:name]
    @subnet.cidr_block = params[:CIDR]

    if params[:internet_accessible] == "true"
      @subnet.internet_accessible = true
    else
      @subnet.internet_accessible = false
    end

    @subnet.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/modify_subnet.js.erb', layout: false }
    end
  end

  def delete_subnet
    if @subnet.instances.size > 0
      @subnet.errors.add(:has_dependents, "Cannot delete subnet because it has dependents")
    else
      @subnet.destroy
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/delete_subnet.js.erb', layout: false }
    end
  end

  def add_instance
    @instance = @subnet.instances.new(
      name: params[:name],
      ip_address: params[:ip],
      os: params[:os],
      internet_accessible: params[:internet_accessible],
      uuid: `uuidgen`.chomp
    )
    @instance.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_instance.js.erb', layout: false }
    end
  end

  def delete_instance
    @instance.destroy

    respond_to do |format|
      format.js { render template: 'scenarios/js/delete_instance.js.erb', layout: false }
    end
  end

  ## Players
  # 

  def add_player
    @player = @group.players.new(login: params[:login], password: params[:password])
    @player.save

    # make login unique for player

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_player.js.erb', layout: false }
    end
  end

  def delete_player
    @player = Player.find(params[:player_id])
    if not @user.owns? @player
      head :ok, content_type: "text/html"
      return
    end

    @player.delete

    respond_to do |format|
      format.js { render template: 'scenarios/js/delete_player.js.erb', layout: false }
    end
  end

  def add_student_group
    # if @scenario.stopped?
      # redirect_to @scenario, notice: "Can not modify players while scenario is booted"
      # return
    # end
    @players = []
    student_group = StudentGroup.where("name = ? AND user_id = #{current_user.id}", params[:student_group]).first
    
    student_group.student_group_users.each do |student_group_user|
        if not @group.players.where("user_id = #{student_group_user.user_id} AND student_group_id = #{student_group.id}").first
          player = @group.players.new(
            login: "student_#{student_group_user.user.id}",
            password: SecureRandom.base64(7),
            user_id: student_group_user.user.id,
            student_group_id: student_group_user.student_group.id
          )
          player.save
          @players.push(player)
        end
    end
    
    respond_to do |format|
      format.js { render template: 'scenarios/js/add_student_group.js.erb', layout: false }
    end
  end

  def remove_student_group
    @players = []
    student_group = StudentGroup.where("name = ? AND user_id = #{current_user.id}", params[:student_group]).first
    
    student_group.student_group_users.each do |student_group_user|
      # if params[:add]
        # if !@group.players.where("user_id = #{student_group_user.user_id} AND student_group_id = #{student_group.id}").first
        # # if !group.players.find_by_user_id(student_group_user.user_id)
          
        #   player = @group.players.new(
        #     login: "student_#{student_group_user.user.id}",
        #     password: SecureRandom.base64(7),
        #     user_id: student_group_user.user.id,
        #     student_group_id: student_group_user.student_group.id
        #   )
        #   player.save
        #   @players.push(player)

        # end
      # elsif params[:remove]

      if player = @group.players.find_by_user_id(student_group_user.user.id)
        @players.push(player)
        player.delete
      end
      # end
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/remove_student_group.js.erb', layout: false }
    end
  end

  ## Helpers

  def get_instance_bash_history
    @bash_history = @instance.get_bash_history.gsub("\n", "<br>").html_safe;
    respond_to do |format|
      format.js { render template: 'scenarios/js/bash_history.js.erb', layout: false }
    end
  end

  def get_log
    if params[:kind] == 'scenario'
      resource = Scenario.find(params[:id])
    elsif params[:kind] == 'cloud'
      resource = Cloud.find(params[:id])
    elsif params[:kind] == 'subnet'
      resource = Subnet.find(params[:id])
    elsif params[:kind] == 'instance'
      resource = Instance.find(params[:id])
    end

    if not @user.owns? resource
      head :ok, content_type: "text/html"
      return
    end

    @htmllog = resource.log.gsub("\n", "<br>").html_safe;
    @name = resource.name

    respond_to do |format|
      format.js { render template: 'scenarios/js/log.js.erb', layout: false }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(current_user.id)
    end

    def set_scenario
      @scenario = Scenario.find(params[:id])
      if not @user.owns? @scenario
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_cloud
      @cloud = Cloud.find(params[:cloud_id])
      if not @user.owns? @cloud
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_subnet
      @subnet = Subnet.find(params[:subnet_id])
      if not @user.owns? @subnet
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_instance
      @instance = Instance.find(params[:instance_id])
      if not @user.owns? @instance
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_group
      @group = Group.find(params[:group_id])
      if not @user.owns? @group
        head :ok, content_type: "text/html"
        return
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scenario_params
      params.require(:scenario).permit(:game_type, :name, :template)
    end
end
