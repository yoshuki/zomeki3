class Feed::Script::FeedsController < ApplicationController
  include

  def read
    success = 0
    error   = 0
    feeds = Feed::Feed.where(state: 'public').all
    if Script.options && Script.options[:site_id]
      site_content_ids = Feed::Content::Feed.where(site_id: Script.options[:site_id]).pluck(:id)
      feeds = feeds.where(content_id: site_content_ids) if site_content_ids.present?
    end
    Script.total feeds.size

    feeds.each do |feed|
      Script.current

      begin
        if feed.update_feed
          Script.success
          success += 1
        else
          raise "DestroyFailed : #{feed.uri}"
        end
      rescue Script::InterruptException => e
        raise e
      rescue => e
        Script.error e
        error += 1
      end
    end

    if error > 0
      puts "Finished. Success: #{success}, Error: #{error}"
      render plain: "NG"
    else
      puts "Finished. Success: #{success}"
      render plain: "OK"
    end
  end
end
