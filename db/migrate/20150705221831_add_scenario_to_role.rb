class AddScenarioToRole < ActiveRecord::Migration
  def change
  	add_column :roles, :scenario_id, :integer
  end
end
