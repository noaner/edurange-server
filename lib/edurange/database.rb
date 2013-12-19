# This file contains two things:
#
# The connection to the in memory database:
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

# and the list of tables to create:

# Scenarios
ActiveRecord::Migration.create_table :scenarios do |t|
  t.string :game_type, null: false
  t.string :name, null: false
  t.timestamps
end

# Monitoring Units
ActiveRecord::Migration.create_table :monitoring_units do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.integer :scenario_id, null: false
  t.timestamps
end

# Subnets
ActiveRecord::Migration.create_table :subnets do |t|
  t.string :cidr_block, null: false
  t.boolean :control, null: false, default: false
  t.integer :monitoring_unit_id, null: false
  t.timestamps
end

# Instances
ActiveRecord::Migration.create_table :instances do |t|
  t.string :cidr_block, null: false
  t.boolean :internet_accessible, null: false, default: false
  t.integer :subnet_id, null: false
  t.timestamps
end

# Roles
ActiveRecord::Migration.create_table :roles do |t|
  t.string :packages # Actually an array, serialized. Same with recipes.
  t.string :recipes 
  t.timestamps
end

# Instances_Roles
ActiveRecord::Migration.create_table :instances_roles do |t|
  t.integer :instance_id, null: false
  t.integer :role_id, null: false
  t.timestamps
end

# Users
ActiveRecord::Migration.create_table :users do |t|
  t.string :login, null: false
  t.string :ssh_key, null: false
  t.timestamps
end

# Instances_Users
ActiveRecord::Migration.create_table :instances_users do |t|
  t.integer :user_id, null: false
  t.integer :instance_id, null: false
  t.boolean :administrator, null: false, default: false
  t.timestamps
end

