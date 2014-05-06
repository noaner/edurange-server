class AddStatusToSubnet < ActiveRecord::Migration
  def change
    add_column :subnets, :status, :integer, default: 0
  end
end
