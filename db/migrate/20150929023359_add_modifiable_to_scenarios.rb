class AddModifiableToScenarios < ActiveRecord::Migration
  def change
    add_column :scenarios, :modifiable, :boolean, default: false
  end
end
