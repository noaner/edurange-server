class AddScoringPagesContentToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :scoring_pages_content, :text, default: ""
  end
end
