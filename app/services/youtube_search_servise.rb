class YoutubeSearchServise
  require "net/http"
  require "json"

  def initialize(keyword)
    @keyword = keyword
    @api_key = ENV["GOOGLE_API_KEY"]
  end

  def search
    cache_file = Rails.root.join("tmp", "youtube_cache_#{@keyword}.json")

    if File.exist?(cache_file)
      json = JSON.parse(File.read(cache_file))
    else
      base_url = "https://www.googleapis.com/youtube/v3/search"
      params = {
        key: @api_key,
        q: @keyword,
        type: "video",
        maxResults: 20,
        part: "snippet"
      }
      uri = URI(base_url)
      uri.query = URI.encode_www_form(params)
      response = Net::HTTP.get_response(uri)
      json = JSON.parse(response.body)

      return [] if json["error"]

      File.write(cache_file, JSON.pretty_generate(json))
    end

    results = json["items"].map do |item|
      {
        title: item["snippet"]["title"],
        channel: item["snippet"]["channelTitle"],
        youtube_url: "https://www.youtube.com/watch?v=#{item['id']['videoId']}"
      }
    end
  end
end
