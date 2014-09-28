class ScenariosController < ApplicationController
  before_action :set_scenario, only: [:show, :edit, :update, :destroy, :status, :boot_toggle, :test_console, :modify_players]

  # GET /scenarios
  # GET /scenarios.json
  def index
    user = User.find(current_user.id)
    @scenarios = []
    if user.is_admin?
      @scenarios = Scenario.all
    else
      @scenarios = Scenario.where(:user_id => current_user.id)
    end
  end

  def status
    @total_booted = 0
    @total_instances = 0

    @scenario.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          if instance.scoring_page.blank?
            next
          end
          @total_instances += 1
          body = Net::HTTP.get(URI(instance.scoring_page))
          puts "GET #{instance.scoring_page}"
          begin
            if Nokogiri.XML(body).children.first.name = 'Error'
            end
          rescue NoMethodError
            @total_booted += 1
          end
        end
      end
    end
    respond_to do |format|
      format.html
      format.json { render json: {total: @total_instances, booted: @total_booted} }
    end
  end
  # GET /scenarios/1
  # GET /scenarios/1.json
  def show
    @user = User.find(current_user.id)
    @cloud_booted = @scenario.clouds.select { |cloud| cloud.booted? }.size
    @cloud_count = @scenario.clouds.size
    @subnet_booted = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.select { |subnet| subnet.booted? }.size
    @subnet_count = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.size
    @instance_booted = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.map { |subnet| subnet.instances }.flatten.select { |instance| instance.booted? }.size
    @instance_count = @scenario.clouds.map { |cloud| cloud.subnets }.flatten.map { |subnet| subnet.instances }.flatten.size
  
    # get studentGroups
    @student_groups = StudentGroup.where("instructor_id = #{current_user.id} AND student_id = #{current_user.id}")

  end

  def boot_toggle
    if @scenario.status == "stopped"
      @scenario.boot
      # @booting = true
      @boot_message = "Scenario is booting. Monitor output below."
    elsif @scenario.status == "booted" or @scenario.status == "unboot_failed" or @scenario.status == "boot_failed"
      @scenario.unboot
      # @unbooting = true
      @boot_message = "Scenario is unbooting. Monitor output below."
    end

    respond_to do |format|
      format.js { render 'scenarios/boot.js.erb', :layout => false }
      format.html { redirect_to @scenario, notice: notice }
    end
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
    if template = scenario_params["template"]
      @scenario = YmlRecord.load_yml("scenarios-yml/#{template}")
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
    @scenario.clouds.each do |cloud|
      cloud.subnets.each do |subnet|
        subnet.instances.each do |instance|
          instance.instance_groups.each do |instance_group|
            Group.where(:id => instance_group.group_id).destroy_all
            Player.where(:group_id => instance_group.group_id).destroy_all
            InstanceGroup.where(:id => instance_group.id).destroy_all
          end
          role_id = InstanceRole.where(:instance_id => instance.id).pluck(:role_id).first
          Role.where(:id => role_id).destroy_all
          Instance.where(:id => instance.id).destroy_all
        end
        Subnet.where(:id => subnet.id).destroy_all
      end
      Cloud.where(:id => cloud.id).destroy_all
    end
    @scenario.destroy

    respond_to do |format|
      format.html { redirect_to scenarios_url, notice: 'Scenario was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def test_console
    @scenario = Scenario.find(params[:id])
    @scenario.delay.debug "-- Test Console Print --"
    redirect_to @scenario, notice: "Testing Console. Output should appear in Console Log. If no output withing a few seconds Console Log is broken."
    
    respond_to do |format|
      format.json {  }
    end
  end

  def modify_players
    if @scenario.status == "booted"
      redirect_to @scenario, notice: "Can not modify players while scenario is booted"
      return
    end
    group = Group.find(params[:group])
    # student_group = StudentGroup.find_by_name(params[:studentGroupName])
    student_group = StudentGroup.where("name = '#{params[:studentGroupName]}' AND user_id = #{current_user.id}").first
    student_group.student_group_users.each do |student_group_user|
      if params[:add]
        if !group.players.where("user_id = #{student_group_user.user_id} AND student_group_id = #{student_group.id}").first
        # if !group.players.find_by_user_id(student_group_user.user_id)
          group.players.new(
            login: "student_#{student_group_user.user.id}",
            password: SecureRandom.base64(7),
            user_id: student_group_user.user.id,
            student_group_id: student_group_user.student_group.id
          ).save
        end
      elsif params[:remove]
        if player = group.players.find_by_user_id(student_group_user.user.id)
          player.destroy
        end
      end
    end
    redirect_to @scenario
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_scenario
      @scenario = Scenario.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scenario_params
      params.require(:scenario).permit(:game_type, :name, :template, :log)
    end
end
