class KeyChain < ActiveRecord::Base
  include FlagShihTzu

  has_many :keys
  has_and_belongs_to_many :users

  # boolean bitfield provided by flag_shih_tzu gem
  # default false
  has_flags 1 => :create_user,
            2 => :create_scenario

  def can?(flag)
    return self.send flag
  end
end
