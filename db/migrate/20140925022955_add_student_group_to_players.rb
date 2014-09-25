class AddStudentGroupToPlayers < ActiveRecord::Migration
  def change
    add_column :players, :student_group_id, :integer
  end
end
