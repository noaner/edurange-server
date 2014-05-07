class ManagementController < ApplicationController
  def clean
    @management = Management.new
    @management.cleanup
    redirect_to management_status_path, notice: "Cleaning up!"
  end
  def purge
    @management = Management.new
    @management.purge
    redirect_to management_status_path, notice: "Purging web db!"
  end
  def status
  end
end
