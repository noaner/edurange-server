class KeyChain < ActiveRecord::Base
  include FlagShihTzu

  has_many :keys
  has_and_belongs_to_many :users

  # boolean bitfield provided by flag_shih_tzu gem
  # default false
  has_flags 1 => :can_create_user,
            2 => :can_create_scenario

  # return all keys to a specific resource
  def keys_for(resource)
    self.keys.select{ |k| k.resource == resource }
  end

  # check whether a flag is set
  def can?(flag)
    return self.send "can_" + flag.to_s
  end

  # set a flag or flags to true
  def can(*flags)
    flags.each do |flag|
      self.send "can_#{flag.to_s}=", true
    end
    self.save
  end

  # set a flag or flags to false
  def cannot(*flags)
    flags.each do |flag|
      self.send "can_#{flag.to_s}=", false
    end
    self.save
  end
end
