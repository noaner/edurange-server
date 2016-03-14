class CreateKeyChains < ActiveRecord::Migration
  def change
    create_table :key_chains do |t|
      t.integer :flags
      t.string :name

      t.timestamps null: false
    end

    create_join_table :key_chains, :users
  end
end
