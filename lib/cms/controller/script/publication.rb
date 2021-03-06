require 'timeout'
class Cms::Controller::Script::Publication < ApplicationController
  include Cms::Controller::Layout
  before_action :initialize_publication

  def self.publishable?
    true
  end

  def initialize_publication
    if @node = params[:node] || Cms::Node.where(id: params[:node_id]).first
      @site = @node.site
    end
    @errors = []
  end

  def publish_page(item, params = {})
    site = params[:site] || @site

    if params[:smart_phone].present?
      return false unless site.publish_for_smart_phone?
      return false unless site.spp_all? || (site.spp_only_top? && item.respond_to?(:top_page?) && item.top_page?)
    end

    ::Script.current

    if ::Script.options
      path = params[:uri].to_s.sub(/\?.*/, '')
      return false if ::Script.options.is_a?(Array) && !::Script.options.include?(path)
      return false if ::Script.options.is_a?(Regexp) && ::Script.options !~ path
    end

    rendered = render_public_as_string(params[:uri], site: site,
                                       jpmobile: (params[:smart_phone] ? envs_to_request_as_smart_phone : nil))
    res  = item.publish_page(rendered, :path => params[:path], :dependent => params[:dependent])
    return false unless res
    #return true if params[:path] !~ /(\/|\.html)$/

    if params[:smart_phone_path].present? && site.publish_for_smart_phone? &&
       (site.spp_all? || (site.spp_only_top? && item.respond_to?(:top_page?) && item.top_page?))

      rendered = render_public_as_string(params[:uri], site: site, jpmobile: envs_to_request_as_smart_phone)
      res = item.publish_page(rendered, path: params[:smart_phone_path], dependent: "#{params[:dependent]}_smart_phone")
      return false unless res
    end

    ::Script.success if item.published?

    ## ruby html
    return true unless Zomeki.config.application['cms.use_kana']
    ids = Zomeki.config.application['cms.use_kana_exclude_site_ids'] || []
    return true if ids.include?(site.id)

    uri = params[:uri]
    if uri =~ /\.html$/
      uri += ".r"
    elsif uri =~ /\/$/
      uri += "index.html.r"
    elsif uri =~ /\/\?/
      uri = uri.gsub(/(\/)(\?)/, '\\1index.html.r\\2')
    elsif uri =~ /\.html\?/
      uri = uri.gsub(/(\.html)(\?)/, '\\1.r\\2')
    else
      return true
    end

    #uri  = (params[:uri] =~ /\.html$/ ? "#{params[:uri]}.r" : "#{params[:uri]}index.html.r")
    path = (params[:path] =~ /\.html$/ ? "#{params[:path]}.r" : "#{params[:path]}index.html.r")
    smart_phone_path = if params[:smart_phone_path].present? && site.publish_for_smart_phone? &&
                          (site.spp_all? || (site.spp_only_top? && item.respond_to?(:top_page?) && item.top_page?))
        params[:smart_phone_path] =~ /\.html$/ ? "#{params[:smart_phone_path]}.r" : "#{params[:smart_phone_path]}index.html.r"
      else
        nil
      end
    dep  = params[:dependent] ? "#{params[:dependent]}/ruby" : "ruby"

    ruby = nil
    if item.published?
      ruby = true
    elsif !::File.exist?(path)
      ruby = true
    elsif ::File.stat(path).mtime < Cms::KanaDictionary.dic_mtime
      ruby = true
    end

    if ruby
      begin
        Timeout.timeout(600) do
          rendered = render_public_as_string(uri, site: site, jpmobile: (params[:smart_phone] ? envs_to_request_as_smart_phone : nil))
          item.publish_page(rendered, :path => path, :dependent => dep)
          if smart_phone_path
            rendered = render_public_as_string(uri, site: site, jpmobile: envs_to_request_as_smart_phone)
            item.publish_page(rendered, path: smart_phone_path, dependent: "#{dep}_smart_phone")
          end
        end
      rescue Timeout::Error => e
        ::Script.error "#{uri} Timeout"
      rescue => e
        ::Script.error "#{uri}\n#{e.message}"
      end
    end

    return res
  rescue => e
    ::Script.error "#{uri}\n#{e.message}"
    error_log e.message
    return false
  end

  def publish_more(item, params = {})
    if params[:period] != 'simple' && params[:target_date].present?
      publish_more_by_period(item, params)
    else
      p = 1
      published = 0
      stopp = nil
      limit = params[:limit] || Zomeki.config.application["cms.publish_more_pages"].to_i rescue 0
      limit = (limit < 1 ? 1 : 1 + limit)
      file  = params[:file] || 'index'
      first = params[:first] || 1
      start_at = params[:start_at] || Date.today
      period = params[:period] || 'simple'
      while published < limit do
        page =  case period
        when 'monthly'
          date = (start_at - ( p - 1 ).month)
          (p == 1 ? "" : (start_at - ( p - 1 ).month).beginning_of_month.strftime('.%Y%m'))
        when 'weekly'
          date = (start_at - ( p - 1 ).week)
          (p == 1 ? "" : (start_at - ( p - 1 ).week).beginning_of_week.strftime('.%Y%m%d'))
        else
          (p == 1 ? "" : ".p#{p}")
        end
        uri  = "#{params[:uri]}#{file}#{page}.html"
        path = "#{params[:path]}#{file}#{page}.html"
        smart_phone_path = (params[:smart_phone_path].present? ? "#{params[:smart_phone_path]}#{file}#{page}.html" : nil)
        dep  = "#{params[:dependent]}#{page}"
        rs = publish_page(item, uri: uri, site: params[:site], path: path, smart_phone_path: smart_phone_path,
                                dependent: dep, smart_phone: params[:smart_phone])
        unless rs
          if period == 'simple'
            stopp = p
            break
          else
            if params[:end_at].blank? || params[:start_at].blank? || params[:end_at] > date
              stopp = p
              break
            end
          end
        end
        p += 1
        published += 1
        #return item.published? ## file updated
      end
    end


    ## remove over files
    del_first = stopp ? stopp : (limit + 1)
    first = 2
    first.upto(100) do |p|
      deps = []
      page_num   = ".p#{p}"
      month_date = (start_at - ( p - 1 ).month).beginning_of_month.strftime('.%Y%m')
      week_date  = (start_at - ( p - 1 ).week).beginning_of_week.strftime('.%Y%m%d')
      case period
      when 'monthly'
        deps << month_date if p >= del_first
        deps << week_date
        deps << page_num
      when 'weekly'
        deps << month_date
        deps << week_date if p >= del_first
        deps << page_num
      else
        deps << month_date
        deps << week_date
        deps << page_num if p >= del_first
      end
      deps.each do |dep|
        d = "#{params[:dependent]}#{dep}"
        pub = Sys::Publisher.find_by(publishable: item, dependent: d)
        next unless pub
        pub.destroy
        pub = Sys::Publisher.find_by(publishable: item, dependent: "#{d}/ruby")
        pub.destroy if pub
      end
    end
  end

  def publish_more_by_period(item, params = {})
    file  = params[:file] || 'index'
    target_date =  Date.parse(params[:target_date])
    dates = case params[:period]
    when 'monthly'
      [
        target_date.beginning_of_month - 1.month,
        target_date.beginning_of_month,
        target_date.beginning_of_month + 1.month,
        target_date.beginning_of_month + 2.month
      ]
    when 'weekly'
      [
        target_date.beginning_of_week - 1.week,
        target_date.beginning_of_week,
        target_date.beginning_of_week + 1.week,
        target_date.beginning_of_week + 2.week
      ]
    else
      []
    end

    dates.each do |date|
      page = dates = case params[:period]
      when 'monthly'
        date.strftime('.%Y%m') == params[:start_at].strftime('.%Y%m') ? "" : date.strftime('.%Y%m')
      when 'weekly'
        date.strftime('.%Y%m%d') == params[:start_at].strftime('.%Y%m%d') ? "" : date.strftime('.%Y%m%d')
      else
        next
      end

      uri  = "#{params[:uri]}#{file}#{page}.html"
      path = "#{params[:path]}#{file}#{page}.html"
      smart_phone_path = (params[:smart_phone_path].present? ? "#{params[:smart_phone_path]}#{file}#{page}.html" : nil)
      dep  = "#{params[:dependent]}#{page}"
      publish_page(item, uri: uri, site: params[:site], path: path, smart_phone_path: smart_phone_path,
                   dependent: dep, smart_phone: params[:smart_phone])
    end
  end
end
