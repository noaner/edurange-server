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
ActiveRecord::Migration.create_table :clouds do |t|
  t.string :cidr_block, null: false
  t.string :driver_id
  t.references :scenario, null: false
  t.timestamps
end

# Subnets
ActiveRecord::Migration.create_table :subnets do |t|
  t.string :cidr_block, null: false
  t.string :driver_id
  t.boolean :control, null: false, default: false
  t.boolean :internet_accessible, null: false, default: false
  t.references :cloud, null: false
  t.timestamps
end

# Instances
ActiveRecord::Migration.create_table :instances do |t|
  t.string :ip_address, null: false
  t.string :driver_id
  t.string :os, null: false
  t.boolean :internet_accessible, null: false, default: false
  t.references :subnet, null: false
  t.timestamps
end

# Roles
ActiveRecord::Migration.create_table :roles do |t|
  t.string :packages # Actually an array, serialized. Same with recipes.
  t.string :recipes 
  t.timestamps
end

# Instances_Roles
ActiveRecord::Migration.create_table :instance_roles do |t|
  t.references :instance, null: false
  t.references :role, null: false
  t.timestamps
end

# Groups
ActiveRecord::Migration.create_table :groups do |t|
  t.string :name
  t.timestamps
end
# Players
ActiveRecord::Migration.create_table :players do |t|
  t.string :login, null: false
  t.string :ssh_key, null: false
  t.references :group, null: false
  t.timestamps
end

# Instances_Groups
ActiveRecord::Migration.create_table :instance_groups do |t|
  t.references :group, null: false
  t.references :instance, null: false
  t.boolean :administrator, null: false, default: false
  t.timestamps
end

