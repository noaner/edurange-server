class AddInstructionsToScenario < ActiveRecord::Migration
    def up
    add_column :scenarios, :instructions, :string
  end

  def down
    remove_column :scenarios, :instructions
  end
end
