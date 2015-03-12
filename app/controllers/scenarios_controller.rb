class ScenariosController < ApplicationController
  before_action :authenticate_admin_or_instructor
  before_action :set_scenario, only: [:show, :edit, :update, :destroy, :status, :boot, :unboot, :boot_status, :modify_players, :modify, :add_cloud, :add_student_group_to_players]
  before_action :set_cloud, only: [:add_subnet]
  before_action :set_subnet, only: [:add_instance]
  before_action :set_instance, only: []

  # GET /scenarios
  # GET /scenarios.json
  def index
    puts "\nSCENARIO INDEX\n"
    @user = User.find(current_user.id)
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
    @user = User.find(current_user.id)
    # @cloud_booted = @scenario.clouds.select { |cloud| cloud.booted? }.size
    # @cloud_count = @scenario.clouds.size
    # @subnet_booted = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.select { |subnet| subnet.booted? }.size
    # @subnet_count = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.size
    # @instance_booted = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.map { |subnet| subnet.instances }.flatten.select { |instance| instance.booted? }.size
    # @instance_count = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.map { |subnet| subnet.instances }.flatten.size

    # get studentGroups
    # @student_groups = StudentGroup.where("instructor_id = #{current_user.id} AND student_id = #{current_user.id}")
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
      @scenario = YmlRecord.load_yml("scenarios/default/#{template}/#{template}.yml")
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
  def destroy
    @scenario.destroy

    respond_to do |format|
      format.html { redirect_to scenarios_url, notice: 'Scenario was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  ## Booting
  #

  def boot
    if @scenario.stopped?
      @scenario.set_booting
      @scenario.delay(queue: 'scenarios').boot(boot_dependents: true, run_asynchronously: Settings.boot_asynchronously)
    end

    @hide_dropdown = true
    respond_to do |format|
      format.js { render 'scenarios/js/boot_status.js.erb', :layout => false }
    end
  end

  def unboot
    if @scenario.booted?
      @scenario.set_unbooting
      @scenario.delay(queue: 'scenarios').unboot(unboot_dependents: true, run_asynchronously: Settings.boot_asynchronously)
    end

    @hide_dropdown = true
    respond_to do |format|
      format.js { render 'scenarios/js/boot_status.js.erb', :layout => false }
    end
  end

  def boot_cloud
    @cloud = Cloud.find(params[:id])
    if not @cloud.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end

    @cloud.set_booting
    @cloud.delay(queue: 'clouds').boot

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_cloud.js.erb', layout: false }
    end
  end

  def unboot_cloud
    @cloud = Cloud.find(params[:id])
    if not @cloud.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end
    @cloud.set_unbooting
    @cloud.delay(queue: 'clouds').unboot

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_cloud.js.erb',  layout: false }
    end
  end

  def boot_subnet
    @subnet = Subnet.find(params[:id])
    if not @subnet.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end

    if not @subnet.cloud.booted?
      @subnet.errors.add(:cloudnotbooted, "Instances Subnet must be booted first")
    else
      @subnet.set_booting
      @subnet.delay(queue: 'subnets').boot
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_subnet.js.erb', layout: false }
    end
  end

  def unboot_subnet
    @subnet = Subnet.find(params[:id])
    if not @subnet.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end

    @subnet.set_unbooting
    @subnet.delay(queue: 'subnets').unboot

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_subnet.js.erb', layout: false }
    end
  end

  def boot_instance
    @instance = Instance.find(params[:id])
    if not @instance.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end

    if not @instance.subnet.booted?
      @instance.errors.add(:subnetnotbooted, "Instances Subnet must be booted first")
    else
      @instance.set_booting
      @instance.delay(queue: 'instances').boot
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/boot_instance.js.erb', layout: false }
    end
  end

  def unboot_instance
    @instance = Instance.find(params[:id])
    if not @instance.owner?(current_user.id)
      head :ok, content_type: "text/html"
      return
    end

    @instance.set_unbooting
    @instance.delay(queue: 'instances').unboot

    respond_to do |format|
      format.js { render template: 'scenarios/js/unboot_instance.js.erb', layout: false }
    end
  end

  ## Resources
  #

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

  end

  def modify

    @scenario.name = params[:name]
    @scenario.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/modify.js.erb', layout: false }
    end
  end

  def modify_cloud
    @cloud = Cloud.find(params[:cloud_id])
    @cloud.name = params[:name]
    @cloud.cidr_block = params[:CIDR]
    @cloud.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/modify_cloud.js.erb', layout: false }
    end
  end

  def add_subnet
    # @subnet = Subnet.find(params[:id])
    @subnet = Subnet.new
    @subnet.errors.add(:name, "FOO")
    @subnet.errors.add(:cidr_block, "FOO")

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_subnet.js.erb', layout: false }
    end
  end

  def modify_subnet
    @subnet = Subnet.find(params[:subnet_id])
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
    @subnet = Subnet.find(params[:id])
    if @subnet.instances.size > 0
      @subnet.errors.add(:has_dependents, "Cannot delete subnet because it has dependents")
    else
     # @subnet.destroy
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
    @instance = Instance.find(params[:id])
    @instance.destroy

    respond_to do |format|
      format.js { render template: 'scenarios/js/delete_instance.js.erb', layout: false }
    end
  end

  ## Players
  # 

  def add_player
    @group = Group.find(params[:group_id])
    @player = @group.players.new(login: params[:login], password: params[:password])
    @player.save

    # make login unique for player

    respond_to do |format|
      format.js { render template: 'scenarios/js/add_player.js.erb', layout: false }
    end
  end

  def delete_player
    @player = Player.find(params[:id]).delete
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
    @group = Group.find(params[:group_id])
    student_group = StudentGroup.where("name = ? AND user_id = #{current_user.id}", params[:student_group]).first
    student_group.student_group_users.each do |student_group_user|
      # if params[:add]
        if !@group.players.where("user_id = #{student_group_user.user_id} AND student_group_id = #{student_group.id}").first
        # if !group.players.find_by_user_id(student_group_user.user_id)
          
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
    @group = Group.find(params[:group_id])
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

  def getlog
    if params[:kind] == 'scenario'
      resource = Scenario.find(params[:id])
    elsif params[:kind] == 'cloud'
      resource = Cloud.find(params[:id])
    elsif params[:kind] == 'subnet'
      resource = Subnet.find(params[:id])
    elsif params[:kind] == 'instance'
      resource = Instance.find(params[:id])
    end

    @htmllog = resource.log.gsub("\n", "<br>").html_safe;
    @name = resource.name

    respond_to do |format|
      format.js { render template: 'scenarios/js/log.js.erb', layout: false }
    end
  end

  def boot_status
    @scenario.get_status
    respond_to do |format|
      format.js { render 'scenarios/js/boot_status.js.erb', :layout => false }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_scenario
      @scenario = Scenario.find(params[:id])
      if (not @scenario.owner?(current_user.id)) and (not User.find(current_user.id).is_admin?)
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_cloud
      @cloud = Cloud.find(params[:cloud_id])
      if (not @cloud.owner?(current_user.id)) and (not User.find(current_user.id).is_admin?)
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_subnet
      @subnet = Subnet.find(params[:subnet_id])
      if (not @subnet.owner?(current_user.id)) and (not User.find(current_user.id).is_admin?)
        head :ok, content_type: "text/html"
        return
      end
    end

    def set_instance
      @instance = Instance.find(params[:instance_id])
      if (not @instance.owner?(current_user.id)) and (not User.find(current_user.id).is_admin?)
        head :ok, content_type: "text/html"
        return
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scenario_params
      params.require(:scenario).permit(:game_type, :name, :template)
    end
end
