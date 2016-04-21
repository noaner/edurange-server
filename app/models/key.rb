class Key < ActiveRecord::Base
  include FlagShihTzu

  belongs_to :resource, polymorphic: true
  belongs_to :key_chain

  validates :key_chain, presence: true
  validates :resource, presence: true

  # boolean bitfield provided by flag_shih_tzu gem
  # default false
  has_flags 1 => :can_view,
            2 => :can_edit,
            3 => :can_destroy

  def can?(flag)
    self.send "can_#{flag.to_s}"
  end

  def can(*flags)
    flags.each do |flag|
      self.send "can_#{flag.to_s}=", true
    end
    self.save
  end
end
