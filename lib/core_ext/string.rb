class String
  def filename_safe
    self.gsub(/\W/, '_').downcase
  end
end