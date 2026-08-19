module Gallery
  # What a workspace sees in the gallery.
  #
  # Only published, live styles. Draft and retired styles are staff concerns and
  # must never reach a customer.
  class TemplateSearch
    FORMATS = %w[image video].freeze
    PER_PAGE = 15

    def initialize(workspace:, format: "image", category: nil, query: nil, page: 1)
      @workspace = workspace
      @format = FORMATS.include?(format.to_s) ? format.to_s : "image"
      @category = category.presence_in(Template::CONTENT_CATEGORIES.keys)
      @query = query.to_s.strip.presence
      @page = [ page.to_i, 1 ].max
    end

    attr_reader :workspace, :format, :category, :query, :page

    def templates
      @templates ||= paginate(filtered)
    end

    def total_count = @total_count ||= filtered.count

    def total_pages = [ (total_count / PER_PAGE.to_f).ceil, 1 ].max

    def photos? = format == "image"

    # Categories that actually have something in them for this format, so the
    # filter row never offers a chip that leads to an empty grid.
    def available_categories
      @available_categories ||=
        Template.published.where(media_format: format)
                .group(:content_category).count
                .sort_by { |_, count| -count }
    end

    # The gallery may only call itself trending when a source has supplied a
    # real signal. Otherwise it says what the ordering actually is.
    def ordering_label
      return "Trending now" if filtered.any?(&:trend_ranked?)

      "Picked by Prachar"
    end

    private

    def filtered
      @filtered ||= begin
        scope = Template.published.where(media_format: format)
        scope = scope.in_category(category) if category
        scope = search(scope) if query
        scope.most_trending
      end
    end

    def search(scope)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope.where("name ILIKE :q OR description ILIKE :q OR array_to_string(style_tags, ' ') ILIKE :q", q: pattern)
    end

    def paginate(scope)
      scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).with_attached_preview.to_a
    end
  end
end
