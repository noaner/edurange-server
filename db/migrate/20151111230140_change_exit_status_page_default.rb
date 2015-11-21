class ChangeExitStatusPageDefault < ActiveRecord::Migration
  def change
    change_column_default :instances, :exit_status_page, ""
  end
end
