module RbConfig
  def self.read(full_path)
    fail("Config file not found: #{full_path}") unless File.exist?(full_path)

    config = YAML.load(File.read(full_path))
    config.each do |k,v|
      self.send(:define_singleton_method, k.to_sym) do
        if v.is_a? Hash
          OpenStruct.new(v)
        else
          v
        end
      end
    end
  end
end
