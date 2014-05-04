class InstanceRolesController < ApplicationController
  before_action :set_instance_role, only: [:show, :edit, :update, :destroy]

  # GET /instance_roles
  # GET /instance_roles.json
  def index
    @instance_roles = InstanceRole.all
  end

  # GET /instance_roles/1
  # GET /instance_roles/1.json
  def show
  end

  # GET /instance_roles/new
  def new
    @instance_role = InstanceRole.new
  end

  # GET /instance_roles/1/edit
  def edit
  end

  # POST /instance_roles
  # POST /instance_roles.json
  def create
    @instance_role = InstanceRole.new(instance_role_params)

    respond_to do |format|
      if @instance_role.save
        format.html { redirect_to @instance_role, notice: 'Instance role was successfully created.' }
        format.json { render :show, status: :created, location: @instance_role }
      else
        format.html { render :new }
        format.json { render json: @instance_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /instance_roles/1
  # PATCH/PUT /instance_roles/1.json
  def update
    respond_to do |format|
      if @instance_role.update(instance_role_params)
        format.html { redirect_to @instance_role, notice: 'Instance role was successfully updated.' }
        format.json { render :show, status: :ok, location: @instance_role }
      else
        format.html { render :edit }
        format.json { render json: @instance_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /instance_roles/1
  # DELETE /instance_roles/1.json
  def destroy
    @instance_role.destroy
    respond_to do |format|
      format.html { redirect_to instance_roles_url, notice: 'Instance role was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_instance_role
      @instance_role = InstanceRole.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def instance_role_params
      params.require(:instance_role).permit(:instance_id, :role_id)
    end
end
