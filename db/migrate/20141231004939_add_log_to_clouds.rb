class AddLogToClouds < ActiveRecord::Migration
  def change
    add_column :clouds, :log, :string, default: ""
  end
end
