class Cms::Admin::Tool::RebuildController < Cms::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  
  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:designer)
    
    if params.key?(:test)
      start = Time.now.to_f
      rs = render_component_into_view(:controller => 'cms/script/nodes', :action => 'publish')
      flash.now[:notice] = "ページを書き出しました。"
    end
  end
  
  def index
    @item = Cms::Node.new(rebuild_params)
    if params[:do] == 'content'
      Core.messages << "再構築： コンテンツ"
      
      items = Cms::Content.where(site_id: Core.site.id)
        .where(Cms::Content.arel_table[:model].matches("%::Doc"))
        .where.not(model: ['GpArticle::Doc'])
      items.where!(id: @item.content_id) if @item.content_id.present?
      items.each do |item|
        ctl = item.model.underscore.pluralize.gsub(/^(.*?)\//, '\1/admin/tool/')
        act = 'rebuild'
        prm = params.merge({:content => item})
        begin
          Core.messages << "#{item.name}"
          render_component_into_view :controller => ctl, :action => act, :params => prm
        rescue => e
          Core.messages << "-- Error #{e}"
        end
      end
      
    end
    
    if !Core.messages.empty?
      max_messages = 3000
      messages = Core.messages.join('<br />')
      if messages.size > max_messages
        messages = ApplicationController.helpers.truncate(messages, :length => max_messages)
      end
      flash[:notice] = ('再構築が終了しました。<br />' + messages).html_safe
      redirect_to :action => :index
    end
  end

  def rebuild_contents
    contents = Cms::Content.where(id: params[:target_content_ids])
    return redirect_to(url_for(action: 'index'), alert: '対象を選択してください。') if contents.empty?

    result_message = ['再構築：コンテンツ']

    contents.each do |content|
      begin
        ctl = content.model.underscore.pluralize.gsub(/^(.*?)\//, '\1/admin/tool/')
        act = 'rebuild'
        prm = params.merge(content_id: content.id)
        result_message << content.name
        result_message << render_component_into_view(:controller => ctl, :action => act, :params => prm)
      rescue => e
        result_message << "-- 失敗 #{e.message}"
      end
    end

    notice_message = '再構築が終了しました。'

    unless result_message.empty?
      max_messages = 3000
      messages = result_message.join('<br />')
      if messages.size > max_messages
        messages = ApplicationController.helpers.truncate(messages, :length => max_messages)
      end
      notice_message << "<br />#{messages}"
    end

    redirect_to url_for(action: 'index'), notice: notice_message.html_safe
  end

  def rebuild_nodes
    nodes = Cms::Node.where(id: params[:target_node_ids])
    return redirect_to(url_for(action: 'index'), alert: '対象を選択してください。') if nodes.empty?

    result_message = ['再構築：ページ']

    results = {ok: 0, ng: 0}
    errors = []

    nodes.each do |node|
      begin
        page = Cms::Node::Page.find(node.id)
        if page.rebuild(render_public_as_string(page.public_uri))
          page.publish_page(render_public_as_string("#{page.public_uri}.r"), path: "#{page.public_path}.r", dependent: :ruby)
          page.rebuild(render_public_as_string(page.public_uri, jpmobile: envs_to_request_as_smart_phone),
                       path: page.public_smart_phone_path, dependent: :smart_phone)
        end
        results[:ok] += 1
      rescue => e
        results[:ng] += 1
        errors << "エラー： #{node.id}, #{node.title}, #{e.message}"
        error_log("Rebuild: #{e.message}")
      end
    end

    result_message.concat(["-- 成功 #{results[:ok]}件", "-- 失敗 #{results[:ng]}件"])
    result_message.concat(errors)

    notice_message = '再構築が終了しました。'

    unless result_message.empty?
      max_messages = 3000
      messages = result_message.join('<br />')
      if messages.size > max_messages
        messages = ApplicationController.helpers.truncate(messages, :length => max_messages)
      end
      notice_message << "<br />#{messages}"
    end

    redirect_to url_for(action: 'index'), notice: notice_message.html_safe
  end

  def rebuild_params
    params.except(:concept).permit(:target_node_ids, :target_content_ids)
  end
end
