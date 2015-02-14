class AddUseridToPlayers < ActiveRecord::Migration
  def up
    add_column :players, :user_id, :integer
  end

  def down
    remove_column :players, :user_id
  end
end
