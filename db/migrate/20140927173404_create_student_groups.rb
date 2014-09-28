class CreateStudentGroups < ActiveRecord::Migration
  def change
    create_table :student_groups do |t|
      t.belongs_to  :user, null: false, default: ""
      t.string      :name, null: false, default: ""
      t.timestamps
    end
    add_index :student_groups, :name, unique: true
  end
end
