class AddLogToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :log, :text
  end
end
