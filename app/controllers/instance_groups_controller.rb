class InstanceGroupsController < ApplicationController
  before_action :set_instance_group, only: [:show, :edit, :update, :destroy]

  # GET /instance_groups
  # GET /instance_groups.json
  def index
    @instance_groups = InstanceGroup.all
  end

  # GET /instance_groups/1
  # GET /instance_groups/1.json
  def show
  end

  # GET /instance_groups/new
  def new
    @instance_group = InstanceGroup.new
  end

  # GET /instance_groups/1/edit
  def edit
  end

  # POST /instance_groups
  # POST /instance_groups.json
  def create
    @instance_group = InstanceGroup.new(instance_group_params)

    respond_to do |format|
      if @instance_group.save
        format.html { redirect_to @instance_group, notice: 'Instance group was successfully created.' }
        format.json { render :show, status: :created, location: @instance_group }
      else
        format.html { render :new }
        format.json { render json: @instance_group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /instance_groups/1
  # PATCH/PUT /instance_groups/1.json
  def update
    respond_to do |format|
      if @instance_group.update(instance_group_params)
        format.html { redirect_to @instance_group, notice: 'Instance group was successfully updated.' }
        format.json { render :show, status: :ok, location: @instance_group }
      else
        format.html { render :edit }
        format.json { render json: @instance_group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /instance_groups/1
  # DELETE /instance_groups/1.json
  def destroy
    @instance_group.destroy
    respond_to do |format|
      format.html { redirect_to instance_groups_url, notice: 'Instance group was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_instance_group
      @instance_group = InstanceGroup.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def instance_group_params
      params.require(:instance_group).permit(:group_id, :instance_id, :administrator)
    end
end
