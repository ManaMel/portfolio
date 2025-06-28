module ApplicationHelper
  def find_youtube_id(video_url)
    if video_url =~ /v=([\w-]{11})/
      Regexp.last_match(1)
    elsif video_url =~ /youtu\.be\/([\w-]{11})/
      Regexp.last_match(1)
    elsif video_url =~ /embed\/([\w-]{11})/
      Regexp.last_match(1)
    else
      nil
    end
  end
end
