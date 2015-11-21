class ChangeScriptLogPageDefault < ActiveRecord::Migration
  def change
    change_column_default :instances, :script_log_page, ""
  end
end
