class CreateQuestions < ActiveRecord::Migration
  def change
    create_table :questions do |t|
      t.integer :order
      t.string  :text
      t.string  :type_of
      t.string  :options, default: []
      t.string  :values
      t.integer :points
      t.integer :points_penalty
      t.references :scenario, index: true
      t.timestamps 
    end
  end
end
