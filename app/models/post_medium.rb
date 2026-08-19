# Join between a post and one of its media assets, ordered.
#
# Rails singularises post_media to PostMedium; the table stays post_media.
class PostMedium < ApplicationRecord
  belongs_to :post
  belongs_to :media_asset

  validates :position, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
