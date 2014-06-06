class AddUuidToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :uuid, :string
  end
end
