class AddScriptLogPageToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :script_log_page, :string
  end
end
