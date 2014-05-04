# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140504223255) do

  create_table "clouds", force: true do |t|
    t.string   "name"
    t.string   "cidr_block"
    t.string   "driver_id"
    t.integer  "scenario_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "clouds", ["scenario_id"], name: "index_clouds_on_scenario_id"

  create_table "groups", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "instance_groups", force: true do |t|
    t.integer  "group_id"
    t.integer  "instance_id"
    t.boolean  "administrator"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "instance_groups", ["group_id"], name: "index_instance_groups_on_group_id"
  add_index "instance_groups", ["instance_id"], name: "index_instance_groups_on_instance_id"

  create_table "instance_roles", force: true do |t|
    t.integer  "instance_id"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "instance_roles", ["instance_id"], name: "index_instance_roles_on_instance_id"
  add_index "instance_roles", ["role_id"], name: "index_instance_roles_on_role_id"

  create_table "instances", force: true do |t|
    t.string   "name"
    t.string   "ip_address"
    t.string   "driver_id"
    t.string   "cookbook_url"
    t.string   "os"
    t.boolean  "internet_accessible"
    t.integer  "subnet_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "instances", ["subnet_id"], name: "index_instances_on_subnet_id"

  create_table "players", force: true do |t|
    t.string   "login"
    t.string   "password"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "players", ["group_id"], name: "index_players_on_group_id"

  create_table "roles", force: true do |t|
    t.string   "name"
    t.string   "packages"
    t.string   "recipes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "scenarios", force: true do |t|
    t.string   "game_type"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subnets", force: true do |t|
    t.string   "name"
    t.string   "cidr_block"
    t.string   "driver_id"
    t.boolean  "internet_accessible"
    t.integer  "cloud_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "subnets", ["cloud_id"], name: "index_subnets_on_cloud_id"

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.integer  "role"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
