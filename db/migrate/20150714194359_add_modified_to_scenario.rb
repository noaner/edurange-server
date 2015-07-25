class AddModifiedToScenario < ActiveRecord::Migration
  def change
  	add_column :scenarios, :modified, :boolean, default: :false
  end
end
