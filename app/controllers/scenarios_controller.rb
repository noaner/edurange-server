class ScenariosController < ApplicationController
  before_action :authenticate_admin_or_instructor
  before_action :set_user, only: [:index, :show, :new, :boot_cloud, :player_delete, :log_get, :set_scenario, :set_cloud, :set_subnet, :set_instance, :clone]
  before_action :set_scenario, only: [:boot, :destroyme, :edit, :show, :status, :update, :unboot, :boot_status, :clone, :modify, :cloud_add, :player_modify, :player_student_group_add,
    :recipe_custom_add, :recipe_global_add, :recipe_global_get, :recipe_remove, :recipe_update, :recipe_update_view, :recipe_view]
  before_action :set_cloud, only: [:boot_cloud, :unboot_cloud, :cloud_delete, :cloud_modify, :subnet_add]
  before_action :set_subnet, only: [:boot_subnet, :unboot_subnet, :subnet_modify, :subnet_delete, :instance_add, :instance_delete]
  before_action :set_instance, only: [:boot_instance, :unboot_instance, :instance_delete, :instance_bash_history_get, :instance_modify]
  before_action :set_group, only: [:player_add, :player_student_group_add, :player_student_group_remove]
  before_action :set_role, only: [:recipe_global_add, :recipe_custom_add, :recipe_global_get, :recipe_remove, :recipe_update]
  before_action :set_recipe, only: [:recipe_global_add, :recipe_custom_add, :recipe_remove, :recipe_update, :recipe_update_view, :recipe_update, :recipe_view]

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

  # GET /scenarios/1
  # GET /scenarios/1.json
  def show
    @clone = params[:clone]
  end

  # GET /scenarios/new
  def new
    @scenario = Scenario.new
    @templates = YmlRecord.yml_headers.map {|filename,name,desc| [name,filename,desc]}
    @templates_user = YmlRecord.yml_headers_user(@user).map {|filename,name,desc| [name,filename,desc]}
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
      @scenario = YmlRecord.load_yml(scenario_params["template"], @user)
    else
      @scenario = Scenario.new(scenario_params)
    end

    # @scenario.user_id = current_user.id
    # @scenario.save!

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
      format.js { render 'scenarios/js/boot_scenario.js.erb', :layout => false }
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

  # SCENARIO
  def clone
    @clone = @scenario.clone(params[:name])
    respond_to do |format|
      format.js { render "scenarios/js/clone.js.erb", layout: false }
    end
  end

  def modify
    @scenario.change_name(params[:name])
    respond_to do |format|
      format.js { render template: 'scenarios/js/scenario_modify.js.erb', layout: false }
    end
  end

  # CLOUD
  def cloud_add
    @cloud = @scenario.clouds.new(name: params[:name], cidr_block: params[:CIDR])
    @cloud.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/cloud_add.js.erb', layout: false }
    end
  end

  def cloud_delete
    if @cloud.subnets.size > 0
      @cloud.errors.add(:has_dependents, "Cannot delete cloud because it has dependents")
    else
      @cloud.destroy
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/cloud_delete.js.erb', layout: false }
    end
  end

  def cloud_modify
    @cloud.name = params[:name]
    @cloud.cidr_block = params[:cidr_block]
    @cloud.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/cloud_modify.js.erb', layout: false }
    end
  end

  # SUBNET
  def subnet_add
    @subnet = @cloud.subnets.new(name: params[:name], cidr_block: params[:cidr_block], internet_accessible: params[:internet_accessible])
    @subnet.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/subnet_add.js.erb', layout: false }
    end
  end

  def subnet_delete
    if @subnet.instances.size > 0
      @subnet.errors.add(:has_dependents, "Cannot delete subnet because it has dependents")
    else
      @subnet.destroy
    end

    respond_to do |format|
      format.js { render template: 'scenarios/js/subnet_delete.js.erb', layout: false }
    end
  end

  def subnet_modify
    @subnet.name = params[:name]
    @subnet.cidr_block = params[:CIDR]

    if params[:internet_accessible] == "true"
      @subnet.internet_accessible = true
    else
      @subnet.internet_accessible = false
    end

    @subnet.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/subnet_modify.js.erb', layout: false }
    end
  end

  # INSTANCE
  def instance_add
    @instance = @subnet.instances.new(
      name: params[:name],
      ip_address: params[:ip],
      os: params[:os],
      internet_accessible: params[:internet_accessible],
      uuid: `uuidgen`.chomp
    )
    @instance.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/instance_add.js.erb', layout: false }
    end
  end

  def instance_delete
    @instance.destroy

    respond_to do |format|
      format.js { render template: 'scenarios/js/instance_delete.js.erb', layout: false }
    end
  end

  def instance_modify
    @accessible_to_not_accessible = ((@instance.internet_accessible == true) and (params[:internet_accessible] == "false"))
    @not_accessible_to_accessible = ((@instance.internet_accessible == false) and (params[:internet_accessible] == "true"))

    @instance.name = params[:name]
    @instance.ip_address = params[:ip_address]
    @instance.internet_accessible = params[:internet_accessible] == "true"
    @instance.os = params[:os]
    @instance.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/instance_modify.js.erb', layout: false }
    end
  end

  ###############################################################
  #  Players

  def player_add
    @player = @group.players.new(login: params[:login], password: params[:password])
    @player.save

    respond_to do |format|
      format.js { render template: 'scenarios/js/player_add.js.erb', layout: false }
    end
  end

  def player_delete
    @player = Player.find(params[:player_id])
    if not @user.owns? @player
      head :ok, content_type: "text/html"
      return
    end

    @player.delete

    respond_to do |format|
      format.js { render template: 'scenarios/js/player_delete.js.erb', layout: false }
    end
  end

  def player_student_group_add
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
      format.js { render template: 'scenarios/js/player_student_group_add.js.erb', layout: false }
    end
  end

  def player_student_group_remove
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
      format.js { render template: 'scenarios/js/player_student_group_remove.js.erb', layout: false }
    end
  end

  ###############################################################
  #  Recipes

  def recipe_custom_add
    @role.add_custom_recipe(params[:recipe], params[:text])
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_custom_add.js.erb', layout: false }
    end
  end

  def recipe_global_add
    @role.add_global_recipe(@recipe)
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_global_add.js.erb', layout: false }
    end
  end

  def recipe_global_get
    @recipes = @role.scenario.get_global_recipes_and_descriptions
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_global_get.js.erb', layout: false }
    end
  end

  def recipe_remove
    @role.remove_recipe @recipe

    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_remove.js.erb', layout: false }
    end
  end

  def recipe_update
    if @global
      head :ok, content_type: "text/html"
      return
    end

    @scenario.recipe_update(@recipe, params[:text])
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_update.js.erb', layout: false }
    end
  end

  def recipe_update_view
    if @global
      @error = "This is a global recipe can not update from here."
    else
      @recipe_text = @scenario.recipe_text(@recipe).gsub("\"", "\\\"").gsub(/\n/, "\\n").gsub(/\r/, "").html_safe;
    end
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_update_view.js.erb', layout: false }
    end
  end

  def recipe_view
    @recipe_text = @scenario.recipe_text(@recipe).gsub("\n", "<br>").gsub(" ", "&nbsp").gsub("'", "\"").gsub(/\r/, "").html_safe;
    respond_to do |format|
      format.js { render template: 'scenarios/js/recipe_view.js.erb', layout: false }
    end
  end

  ###############################################################
  #  Helpers

  def instance_bash_history
    @bash_history = @instance.get_bash_history.gsub("\n", "<br>").html_safe;
    respond_to do |format|
      format.js { render template: 'scenarios/js/bash_history.js.erb', layout: false }
    end
  end

  def log_get
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

    def set_role
      @role = @scenario.roles.find(params[:role_id]).first
    end

    def set_recipe
      @recipe = params[:recipe].filename_safe
      @global = false
      @global = true if File.exists? "#{Settings.app_path}scenarios/recipes/#{@recipe}.rb.erb"
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scenario_params
      params.require(:scenario).permit(:game_type, :name, :template)
    end
end
