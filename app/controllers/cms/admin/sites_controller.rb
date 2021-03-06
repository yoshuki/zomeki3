require 'yaml/store'

class Cms::Admin::SitesController < Cms::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base

  def pre_dispatch
    return error_auth unless Core.user.has_auth?(:manager)
  end

  def index
    @item = Cms::Site.new # for search

    @items = Cms::Site.order(:id)
    # システム管理者以外は所属サイトしか操作できない
    @items = @items.where(id: current_user.site_ids) unless current_user.root?
    @items = @items.paginate(page: params[:page], per_page: params[:limit])

    _index @items
  end

  def show
    @item = Cms::Site.find(params[:id])
    return error_auth unless @item.readable?

    @item.load_file_transfer
    @item.load_site_settings

    _show @item
  end

  def new
    return error_auth unless Core.user.root? || Core.user.site_creatable?

    @item = Cms::Site.new(
      :state      => 'public',
    )
  end

  def create
    return error_auth unless Core.user.root? || Core.user.site_creatable?

    @item = Cms::Site.new(site_params)
    @item.state = 'public'
    @item.portal_group_state = 'visible'
    @item.load_site_settings
    _create(@item, notice: "登録処理が完了しました。 （反映にはWebサーバーの再起動が必要です。）") do

      @item.users << Core.user unless Core.user.root?
      update_configs
    end
  end

  def update
    @item = Cms::Site.find(params[:id])
    @item.load_site_settings

    @item.attributes = site_params
    _update @item do
      update_configs
      FileUtils.rm_rf Pathname.new(@item.public_smart_phone_path).children if ::File.exist?(@item.public_smart_phone_path) && !@item.publish_for_smart_phone?
    end
  end

  def destroy
    @item = Cms::Site.find(params[:id])
    _destroy(@item) do
      cookies.delete(:cms_site)
      update_configs
    end
  end

  protected

  def update_configs
    Cms::Site.generate_apache_configs
    Cms::Site.generate_apache_admin_configs
    Cms::Site.generate_nginx_configs
    Cms::Site.generate_nginx_admin_configs
    Cms::Site.reload_nginx_servers
  end

  private

  def site_params
    params.require(:item).permit(
      :body, :full_uri, :in_setting_site_admin_protocol, :in_setting_transfer_dest_dir,
      :in_setting_transfer_dest_domain, :in_setting_transfer_dest_host, :in_setting_transfer_dest_user,
      :mobile_full_uri, :admin_full_uri, :name, :og_description, :og_image, :og_title, :og_type, :related_site,
      :smart_phone_publication, :spp_target, :site_image, :del_site_image, :google_map_api_key,
      :in_setting_pass_reminder_mail_sender, :in_setting_file_upload_max_size, :in_setting_extension_upload_max_size,
      :creator_attributes => [:id, :group_id, :user_id]
    )
  end
end
