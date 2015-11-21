class ChangeExitStatusToNotNull < ActiveRecord::Migration
  def change
    change_column_null :statistics, :exit_status, ""
  end
end
