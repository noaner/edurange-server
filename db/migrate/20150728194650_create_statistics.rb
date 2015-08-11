class CreateStatistics < ActiveRecord::Migration
  def change
    create_table :statistics do |t|
      t.belongs_to :user
      t.timestamps null: false
      t.string :bash_histories, :default => '' 
      
      t.text :bash_analytics, :default => []
      t.string :scenario_name
      t.datetime :scenario_created_at	
    end
  end
end
