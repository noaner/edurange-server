class ChangeIpAddressDynamicDefault < ActiveRecord::Migration
  def up
    change_column_default :instances, :ip_address_dynamic, ""
  end

  def down
  	change_column_default :instances, :ip_address_dynamic, nil
  end
end
