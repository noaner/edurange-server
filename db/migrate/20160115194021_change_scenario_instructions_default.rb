class ChangeScenarioInstructionsDefault < ActiveRecord::Migration
  def up
    change_column_default :scenarios, :instructions, ""
  end

  def down
    change_column_default :scenarios, :instructions, nil
  end
end
