class AddRegistrationCodeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :registration_code, :string
  end
end
