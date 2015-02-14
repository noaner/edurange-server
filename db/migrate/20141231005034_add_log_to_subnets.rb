class AddLogToSubnets < ActiveRecord::Migration
  def change
    add_column :subnets, :log, :string, default: ""
  end
end
