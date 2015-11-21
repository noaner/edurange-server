class AddScriptLogToStatistic < ActiveRecord::Migration
  def change
    add_column :statistics, :script_log, :string
  end
end
