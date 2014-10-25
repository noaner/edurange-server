class AddSgrulesToClouds < ActiveRecord::Migration
  def change
    add_column :clouds, :ingress_rules, :string
    add_column :clouds, :egress_rules, :string
  end
end
