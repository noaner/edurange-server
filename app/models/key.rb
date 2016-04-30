class Key < ActiveRecord::Base
  include FlagShihTzu   # provides has_flags for boolean bitfield

  belongs_to :resource, polymorphic: true
  belongs_to :user, dependent: :destroy

  validates :user, presence: true
  validates :resource, presence: true

  DEFAULT_FLAGS = [:edit, :view, :destroy]
  FLAG_LIMIT = 16

  # This basically creates the properties flag_1 through flag_16 for the model.
  # If I were less lazy I'd hard code the bitwise logic, since FlagShihTzu
  # wasn't made for this and adds a lot of cruft by defining functions for each
  # flag.
  (1..16).each do |i|
    has_flags i => "flag_#{i}".to_sym
  end

  def flags_for(obj)
    # return a list of flags for an object
    if defined? obj.class::CAN
      obj.class::CAN
    else
      DEFAULT_FLAGS
    end
  end

  def flag_name(flag)
    # map named flag (e.g. :edit) to a numbered flag (e.g. flag_2)
    index = flags_for(self.resource).index(flag) + 1
    raise OutOfFlagColumns if index > FLAG_LIMIT
    "flag_#{index}"
  end

  def can?(flag)
    # test whether a flag is set
    self.send flag_name(flag)
  end

  def can!(*flags)
    # set a flag or flags to true
    flags.each do |flag|
      self.send "#{flag_name(flag)}=", true
    end
    self.save
  end

  def cannot!(*flags)
    # set a flag or flags to false
    flags.each do |flag|
      self.send "#{flag_name(flag)}=", false
    end
    self.save
  end

  def set_all_flags(value)
    # set all flags to a value
    flags_for(self.resource).each do |flag|
      self.send "#{flag_name(flag)}=", value
    end
  end

  def owns?
    # returns true if every flag is set
    flags_for(self.resource).each do |flag|
      return false if not self.send "#{flag_name(flag)}"
    end

    return true
  end
end
