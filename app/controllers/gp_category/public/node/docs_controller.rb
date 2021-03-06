class GpCategory::Public::Node::DocsController < Cms::Controller::Public::Base
  include GpArticle::Controller::Feed

  def pre_dispatch
    @content = GpCategory::Content::CategoryType.find_by(id: Page.current_node.content.id)
    return http_error(404) unless @content
  end

  def index
    categories = @content.public_category_types.inject([]) {|result, ct|
                     result | ct.public_root_categories.inject([]) {|r, c| r | c.descendants }
                   }
    @docs = GpArticle::Doc.categorized_into(categories.map(&:id)).mobile(::Page.mobile?).public_state
                          .order(display_published_at: :desc, published_at: :desc)

    if params[:format].in?(['rss', 'atom'])
      @docs = @docs.display_published_after(@content.feed_docs_period.to_i.days.ago) if @content.feed_docs_period.present?
      @docs = @docs.paginate(page: params[:page], per_page: @content.feed_docs_number)
      return render_feed(@docs)
    end
    @docs = @docs.paginate(page: params[:page], per_page: @content.doc_docs_number)
    return http_error(404) if @docs.current_page > @docs.total_pages

    if Page.mobile?
      render :index_mobile
    else
      if (style = @content.doc_style).present?
        render style
      end
    end
  end
end
