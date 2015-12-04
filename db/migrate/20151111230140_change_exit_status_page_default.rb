class ChangeExitStatusPageDefault < ActiveRecord::Migration
  def up
    change_column_default :instances, :exit_status_page, ""
  end

  def down
    change_column_default :instances, :exit_status_page, nil
  end
end
