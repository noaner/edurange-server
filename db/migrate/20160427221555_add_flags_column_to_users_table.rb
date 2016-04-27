class AddFlagsColumnToUsersTable < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.integer :flags, null: false, default: 0
    end
  end
end
