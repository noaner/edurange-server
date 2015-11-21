class ChangeExitStatusDefault < ActiveRecord::Migration
  def change
    change_column_default :statistics, :exit_status, ""
  end
end
