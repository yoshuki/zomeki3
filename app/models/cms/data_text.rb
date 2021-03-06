class Cms::DataText < ApplicationRecord
  include Sys::Model::Base
  include Sys::Model::Base::Page
  include Sys::Model::Rel::Creator
  include Cms::Model::Rel::Site
  include Cms::Model::Rel::Concept
  include Cms::Model::Rel::Bracketee
  include Cms::Model::Auth::Concept::Creator

  include StateText
  include Cms::Base::PublishQueue::Bracketee

  belongs_to :concept, :foreign_key => :concept_id, :class_name => 'Cms::Concept'
  
  validates :state, :title, :body, presence: true
  validates :name, presence: true, uniqueness: { scope: :concept_id },
    format: { with: /\A[0-9a-zA-Z\-_]+\z/, if: "name.present?", message: "は半角英数字、ハイフン、アンダースコアで入力してください。" }

  scope :public_state, -> { where(state: 'public') }
end
