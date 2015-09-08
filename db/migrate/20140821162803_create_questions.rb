class CreateQuestions < ActiveRecord::Migration
  def change
    create_table :questions do |t|
      t.string  :answer_id
      t.string  :kind
      t.string  :question_text
      t.string  :answer_text
      t.references :scenario, index: true
      t.timestamps 
    end
  end
end
