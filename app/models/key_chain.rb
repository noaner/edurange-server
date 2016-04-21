class KeyChain < ActiveRecord::Base
  include FlagShihTzu

  has_many :keys
  has_and_belongs_to_many :users

  # boolean bitfield provided by flag_shih_tzu gem
  # default false
  has_flags 1 => :can_create_user,
            2 => :can_create_scenario

  def can?(flag)
    return self.send "can_" + flag.to_s
  end

  def keys_for(resource)
    self.keys.select{ |k| k.resource == resource }
  end
end
