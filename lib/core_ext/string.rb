class String
  def filename_safe
    self.gsub(/[^0-9A-z\-]/, '_').downcase
  end
end