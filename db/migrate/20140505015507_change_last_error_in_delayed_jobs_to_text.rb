class ChangeLastErrorInDelayedJobsToText < ActiveRecord::Migration
  def change
    change_column :delayed_jobs, :last_error, :text
  end
end
