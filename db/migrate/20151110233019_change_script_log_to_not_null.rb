class ChangeScriptLogToNotNull < ActiveRecord::Migration
  def change
    change_column_null :statistics, :script_log, ""
  end
end
