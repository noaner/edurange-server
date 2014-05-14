class AddScoringUrlToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :scoring_url, :string
  end
end
