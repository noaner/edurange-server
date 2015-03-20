class AddBashHistoryPageToInstances < ActiveRecord::Migration
  def change
    add_column :instances, :bash_history_page, :string, default: ""
  end
end
