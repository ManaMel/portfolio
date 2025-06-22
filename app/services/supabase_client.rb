require "net/http"
require "uri"
require "json"

class SupabaseClient
  API_URL = ENV["SUPABASE_API_URL"]
  SERVICE_ROLE_KEY = ENV["SUPABASE_SERVICE_ROLE_KEY"]

  def initialize
    @uri = URI(API_URL)
  end

  def get_users
    url = URI("#{API_URL}/rest/v1/users")
    req = Net::HTTP::Get.new(url)
    req["apikey"] = SERVICE_ROLE_KEY
    req["Authorization"] = "Bearer #{SERVICE_ROLE_KEY}"
    req["Content-Type"] = "application/json"

    res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
      http.request(req)
    end

    JSON.parse(res.body)
  end

  def create_user(user_params)
    url = URI("#{API_URL}/rest/v1/users")
    req = Net::HTTP::Post.new(url)
    req["apikey"] = SERVICE_ROLE_KEY
    req["Authorization"] = "Bearer #{SERVICE_ROLE_KEY}"
    req["Content-Type"] = "application/json"
    req.body = user_params.to_json

    res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
      http.request(req)
  end

    JSON.parse(res.body)
  end
end
