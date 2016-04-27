class CreateKeys < ActiveRecord::Migration
  def change
    create_table :keys do |t|
      t.references :resource, polymorphic: true, null: false, index: true
      t.references :user, null: false, index: true
      t.integer :flags, null: false, default: 0

      t.timestamps null: false
    end
  end
end
