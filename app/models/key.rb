class Key < ActiveRecord::Base
  include FlagShihTzu

  belongs_to :resource, polymorphic: true
  belongs_to :user, dependent: :destroy

  validates :user, presence: true
  validates :resource, presence: true

  DEFAULT_FLAGS = [:edit, :view, :destroy]
  FLAG_LIMIT = 16

  # boolean bitfield provided by flag_shih_tzu gem
  # default false
  (1..16).each do |i|
    has_flags i => "flag_#{i}".to_sym
  end

  def flags_for(obj)
    if defined? obj.class::FLAGS
      obj.class::FLAGS
    else
      DEFAULT_FLAGS
    end
  end

  def flag_name(flag)
    "flag_#{flags_for(self.resource).index(flag) + 1}"
  end

  # test whether a flag is set
  def can?(flag)
    self.send flag_name(flag)
  end

  # set a flag or flags to true
  def can!(*flags)
    flags.each do |flag|
      self.send "#{flag_name(flag)}=", true
    end
    self.save
  end

  # set a flag or flags to false
  def cannot!(*flags)
    flags.each do |flag|
      self.send "#{flag_name(flag)}=", false
    end
    self.save
  end

  # set all flags to a value
  def set_all_flags(value)
    flags_for(self.resource).each do |flag|
      self.send "#{flag_name(flag)}=", value
    end
  end
end
