class AddExitStatusToStatistic < ActiveRecord::Migration
  def change
    add_column :statistics, :exit_status, :string
  end
end
