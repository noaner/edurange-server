class AddAnswersToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :answers, :text, required: true
  end
end