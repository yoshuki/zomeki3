# encoding: utf-8
class GpArticle::Piece::RecentTab < Cms::Piece
  default_scope where(model: 'GpArticle::RecentTab')

  validate :validate_settings

  def validate_settings
    if (lc = in_settings['list_count']).present?
      errors.add(:base, "#{self.class.human_attribute_name :list_count} #{errors.generate_message(:base, :not_a_number)}") unless lc =~ /^[0-9]+$/
    end
  end

  def list_count
    (setting_value(:list_count).presence || 10).to_i
  end

  def more_label
    setting_value(:more_label) || ''
  end

  def content
    GpArticle::Content::Doc.find(super)
  end

  def category_types
    content.category_types
  end

  def category_types_for_option
    category_types.map {|ct| [ct.title, ct.id] }
  end
end
