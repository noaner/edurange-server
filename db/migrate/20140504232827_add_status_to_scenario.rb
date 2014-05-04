class AddStatusToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :status, :integer, default: 0
  end
end
