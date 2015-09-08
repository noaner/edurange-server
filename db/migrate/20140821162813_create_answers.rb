class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.belongs_to 	:user
      t.string  		:text
      t.text        :text_essay
      t.text        :comment
      t.boolean 		:correct
      t.integer			:value_index
      t.string      :essay_points_earned
      t.references 	:question, index: true
      t.timestamps
    end
  end
end
