class AddDefaultValueToAnswers < ActiveRecord::Migration
  def up
  	change_column :scenarios, :answers, :string, default: ""
  end

  def down
  	change_column :scenarios, :answers, :string, default: nil
  end
end
