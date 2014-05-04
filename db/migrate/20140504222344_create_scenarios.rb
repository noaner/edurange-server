class CreateScenarios < ActiveRecord::Migration
  def change
    create_table :scenarios do |t|
      t.string :game_type
      t.string :name

      t.timestamps
    end
  end
end
