class AddStatusToCloud < ActiveRecord::Migration
  def change
    add_column :clouds, :status, :integer, default: 0
  end
end
