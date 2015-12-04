class AddIpAddressDynamicToInstance < ActiveRecord::Migration
  def change
    add_column :instances, :ip_address_dynamic, :string, default: nil
  end
end
