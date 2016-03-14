class Key < ActiveRecord::Base
  include FlagShihTzu

  belongs_to :resource, polymorphic: true
  belongs_to :key_chain

  validates :key_chain, presence: true
  validates :resource, presence: true

  # boolean bitfield provided by flag_shih_tzu gem
  has_flags 1 => :can_view,
            2 => :can_edit,
            3 => :can_destroy
end
