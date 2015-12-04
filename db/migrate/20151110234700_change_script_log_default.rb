class ChangeScriptLogDefault < ActiveRecord::Migration
  def up
    change_column_default :statistics, :script_log, ""
  end

  def down
    change_column_default :statistics, :script_log, nil
  end
end
