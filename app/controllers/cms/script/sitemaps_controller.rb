class Cms::Script::SitemapsController < Cms::Controller::Script::Publication
  def publish
    publish_page(@node, :uri => @node.public_uri, :site => @node.site, :path => @node.public_path)
    
    render plain: (@errors.size == 0 ? "OK" : @errors.join("\n"))
  end
end
