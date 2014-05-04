class CreateInstances < ActiveRecord::Migration
  def change
    create_table :instances do |t|
      t.string :name
      t.string :ip_address
      t.string :driver_id
      t.string :cookbook_url
      t.string :os
      t.boolean :internet_accessible
      t.references :subnet, index: true

      t.timestamps
    end
  end
end
