class AddStatusToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :status, :integer, default: 0
  end
end
