class AddLocationToScenario < ActiveRecord::Migration
  def change
  	add_column :scenarios, :location, :integer, default: 0
  	remove_column :scenarios, :custom
  end
end
