module PortalGroup::Model::Rel::Thread::Attribute
  attr_accessor :in_portal_attribute_ids
  
  def in_portal_attribute_ids
    unless (val = @in_portal_attribute_ids)
      @in_portal_attribute_ids = portal_attribute_ids.to_s.split(' ').uniq
    end
    @in_portal_attribute_ids
  end
  
  def in_portal_attribute_ids=(ids)
    _ids = []
    if ids.class == Array
      ids.each {|val| _ids << val}
      @portal_attribute_ids = _ids.join(' ')
    elsif ids.class == Hash || ids.class == HashWithIndifferentAccess
      ids.each {|key, val| _ids << val}
      @portal_attribute_ids = _ids.join(' ')
    else
      @portal_attribute_ids = ids
    end
  end
  
  def portal_attribute_items
    ids = portal_attribute_ids.to_s.split(' ').uniq
    return [] if ids.size == 0
    item = PortalGroup::Attribute.new
    item.and :id, 'IN', ids
    item.find(:all)
  end
  
  def portal_attribute_is(attr)
    return self if attr.blank?
    attr = [attr] unless attr.class == Array
    cond = Condition.new
    attr.each do |c|
      cond.or :portal_attribute_ids, 'REGEXP', "(^| )#{c.id}( |$)"
    end
    self.and cond
  end
end
