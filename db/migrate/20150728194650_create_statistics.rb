class CreateStatistics < ActiveRecord::Migration
  def change
    create_table :statistics do |t|
      t.belongs_to :user
      t.timestamps null: false
      t.string :bash_histories
    end
  end
end
