class ChangeScriptLogDefault < ActiveRecord::Migration
  def change
    change_column_default :statistics, :script_log, ""
  end
end
