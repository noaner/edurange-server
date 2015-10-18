class RemoveRecipesFromRoles < ActiveRecord::Migration
  def change
  	remove_column :roles, :recipes, :string
  end
end
