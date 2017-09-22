module Path
  def self.root(p = '')
    base = File.expand_path('../..', __FILE__)
    File.join(base, p)
  end
end
