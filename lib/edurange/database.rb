# This file contains two things:
#
# The connection to the in memory database:
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

# and the list of tables to create:

# Scenarios
ActiveRecord::Migration.create_table :scenarios do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.timestamps
end
# Monitoring Units
ActiveRecord::Migration.create_table :monitoring_units do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.timestamps
end

# Subnets
ActiveRecord::Migration.create_table :subnets do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.timestamps
end

# Instances
ActiveRecord::Migration.create_table :instances do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.timestamps
end

# Roles 
ActiveRecord::Migration.create_table :roles do |t|
  t.string :packages
  t.string :recipes
  t.timestamps
end


