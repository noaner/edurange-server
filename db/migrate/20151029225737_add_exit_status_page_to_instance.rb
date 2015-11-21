class AddExitStatusPageToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :exit_status_page, :string
  end
end
