class CreateScenarios < ActiveRecord::Migration
  def change
    create_table :scenarios do |t|
      t.string :name, required: true
      t.string :description, required: true

      t.timestamps
    end
  end
end
