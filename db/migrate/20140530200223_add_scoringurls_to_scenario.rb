class AddScoringurlsToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :scoring_urls, :string
  end
end
