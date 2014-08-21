class AddOrganizationToUsers < ActiveRecord::Migration
  def up
    add_column :users, :organization, :string
  end

  def down
    remove_column :users, :organization
  end
end
