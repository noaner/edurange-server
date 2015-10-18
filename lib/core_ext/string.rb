class String
  def filename_safe
    self.gsub(/\W/, '_').downcase
  end

  def is_integer?
    return ((/^[-+]?[0-9]+$/.match(self) == nil) ? false : true)
  end

  def is_decimal?
    return ((/^[-+]?([0-9]+)?\.[0-9]+$/.match(self) == nil) ? false : true)
  end

  def is_hex?
    return ((/^0[xX][0-9a-fA-F]+$/.match(self) == nil) ? false : true)
  end

  def is_numeric?
    return (self.is_integer? or self.is_decimal? or self.is_hex?)
  end

end