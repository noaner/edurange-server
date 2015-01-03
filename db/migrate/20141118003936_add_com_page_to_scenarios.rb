class AddComPageToScenarios < ActiveRecord::Migration
  def change
    add_column :scenarios, :com_page, :string
  end
end
