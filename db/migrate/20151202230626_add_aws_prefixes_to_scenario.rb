class AddAwsPrefixesToScenario < ActiveRecord::Migration
  def change
    add_column :scenarios, :aws_prefixes, :string
  end
end
