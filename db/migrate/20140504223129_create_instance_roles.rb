class CreateInstanceRoles < ActiveRecord::Migration
  def change
    create_table :instance_roles do |t|
      t.references :instance, index: true
      t.references :role, index: true

      t.timestamps
    end
  end
end
