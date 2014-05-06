class ManagementController < ApplicationController
  def clean
    @management = Management.new
    @management.cleanup
    redirect_to management_status_path, notice: "Cleaning up!"
  end
  def status
  end
end
