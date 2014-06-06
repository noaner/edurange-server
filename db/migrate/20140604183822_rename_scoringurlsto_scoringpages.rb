class RenameScoringurlstoScoringpages < ActiveRecord::Migration
  def change
    rename_column :scenarios, :scoring_urls, :scoring_pages
  end
end
