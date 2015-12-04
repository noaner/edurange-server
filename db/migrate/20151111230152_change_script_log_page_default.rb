class ChangeScriptLogPageDefault < ActiveRecord::Migration
  def up
    change_column_default :instances, :script_log_page, ""
  end

  def down
  	change_column_default :instances, :script_log_page, nil
  end
end
