module API
  # DEFAULT_GET_HEADERS = {
  #   "Authorization" => RbConfig.auth_token,
  #   "Accept" => "application/json"
  # }

  # DEFAULT_POST_HEADERS = {
  #   "Authorization" => RbConfig.auth_token,
  #   "Accept" => "application/json",
  #   "Content-Type" => "application/json"
  # }

  def self.get(path, headers = default_get_headers)
    HTTParty.get(url(path), timeout: 15, headers: headers)
  end

  def self.post(path, data, headers = default_post_headers)
    HTTParty.post(url(path), body: data.to_json, timeout: 15, headers: headers)
  end

  def self.url(path)
    "#{RbConfig.patterns_url}#{path}"
  end

  def self.default_get_headers
    {
      "Authorization" => RbConfig.auth_token,
      "Accept" => "application/json"
    }
  end

  def self.default_post_headers
    {
      "Authorization" => RbConfig.auth_token,
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end
end
