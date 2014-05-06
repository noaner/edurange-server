class CreateSubnets < ActiveRecord::Migration
  def change
    create_table :subnets do |t|
      t.string :name, required: true
      t.string :cidr_block, required: true
      t.string :driver_id
      t.boolean :internet_accessible, required: true, default: false
      t.references :cloud, index: true

      t.timestamps
    end
  end
end
