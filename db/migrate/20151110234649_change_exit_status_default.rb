class ChangeExitStatusDefault < ActiveRecord::Migration
  def up
    change_column_default :statistics, :exit_status, ""
  end

  def down
    change_column_default :statistics, :exit_status, nil
  end
end
