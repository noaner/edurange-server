class AddAnswersurlToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :answers_url, :string
  end
end
