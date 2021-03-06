ZomekiCMS::Application.routes.draw do
  mod = 'gnav'

  ## script
  get "/_script/#{mod}/script/menu_items/publish" => "#{mod}/script/menu_items#publish"

  ## admin
  scope "#{ZomekiCMS::ADMIN_URL_PREFIX}/#{mod}/c:concept", :module => mod, :as => mod do
    resources :content_base,
      :controller => 'admin/content/base'

    resources :content_settings, :only => [:index, :show, :edit, :update],
      :controller => 'admin/content/settings',
      :path       => ':content/content_settings'

    ## contents
    resources :menu_items,
      :controller => 'admin/menu_items',
      :path       => ':content/menu_items'

    ## nodes
    resources :node_menu_items,
      :controller => 'admin/node/menu_items',
      :path       => ':parent/node_menu_items'

    ## pieces
    resources :piece_category_types,
      :controller => 'admin/piece/category_types'
    resources :piece_docs,
      :controller => 'admin/piece/docs'
  end

  ## public
  scope "_public/#{mod}", :module => mod, :as => '' do
    get 'node_menu_items(/index.:format)' => 'public/node/menu_items#index'
    get 'node_menu_items/:name(/index.:format)' => 'public/node/menu_items#show'
  end
end
