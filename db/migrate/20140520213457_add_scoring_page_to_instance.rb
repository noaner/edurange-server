class AddScoringPageToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :scoring_page, :string
  end
end
