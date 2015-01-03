class AddLogToInstances < ActiveRecord::Migration
  def change
    add_column :instances, :log, :string, default: ""
  end
end
