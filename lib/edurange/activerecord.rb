# This file contains two things:
#
# The connection to the in memory database:
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

# and the list of tables to create:
#
# Monitoring Units
ActiveRecord::Migration.create_table :monitoring_units do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.timestamps
end
