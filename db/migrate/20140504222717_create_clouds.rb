class CreateClouds < ActiveRecord::Migration
  def change
    create_table :clouds do |t|
      t.string :name
      t.string :cidr_block
      t.string :driver_id
      t.references :scenario, index: true

      t.timestamps
    end
  end
end
