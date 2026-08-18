# The one page title treatment, so every screen reads the same (spec 19, 21).
class PageHeadingComponent < ApplicationComponent
  renders_one :actions
  renders_one :eyebrow

  def initialize(title:, subtitle: nil, level: 1)
    @title = title
    @subtitle = subtitle
    @level = level
  end

  attr_reader :title, :subtitle, :level
end
