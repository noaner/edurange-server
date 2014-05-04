class CreateSubnets < ActiveRecord::Migration
  def change
    create_table :subnets do |t|
      t.string :name
      t.string :cidr_block
      t.string :driver_id
      t.boolean :internet_accessible
      t.references :cloud, index: true

      t.timestamps
    end
  end
end
