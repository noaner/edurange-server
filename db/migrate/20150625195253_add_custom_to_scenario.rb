class AddCustomToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :custom, :boolean
  end
end
