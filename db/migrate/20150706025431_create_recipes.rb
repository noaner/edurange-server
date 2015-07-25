class CreateRecipes < ActiveRecord::Migration
  def change
    create_table :recipes do |t|
      t.belongs_to  :scenario
      t.string  :name, required: true
      t.boolean  :custom, required: true
      t.timestamps null: false
    end
  end
end
