class CreateKeys < ActiveRecord::Migration
  def change
    create_table :keys do |t|
      t.references :resource, polymorphic: true, index: true
      t.references :key_chain, index: true, foreign_key: true
      t.integer :flags

      t.timestamps null: false
    end
  end
end
