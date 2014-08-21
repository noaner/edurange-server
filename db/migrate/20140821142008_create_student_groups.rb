class CreateStudentGroups < ActiveRecord::Migration
  def change
    create_table :student_groups do |t|
      t.integer :instructor_id
      t.integer :student_id
      t.string  :name
    end
  end
end
