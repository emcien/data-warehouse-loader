%w(httparty trollop pry yaml logger mysql2).each do |gem|
  require gem
end

%w(path config api).each do |lib|
  require_relative "./#{lib}"
end
