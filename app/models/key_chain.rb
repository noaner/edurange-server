class KeyChain < ActiveRecord::Base
  include FlagShihTzu

  has_many :keys
  has_and_belongs_to_many :users

  # boolean bitfield provided by flag_shih_tzu gem
  has_flags 1 => :can_create_user,
            2 => :can_create_scenario
end
