class AddComPageToInstances < ActiveRecord::Migration
  def change
    add_column :instances, :com_page, :string
  end
end
