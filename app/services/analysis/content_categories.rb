module Analysis
  # Derived from the catalog the owner just entered, which is real data, rather
  # than from post history, which does not exist yet.
  class ContentCategories < Analyzer
    def call
      categories = (workspace.products.pluck(:category) + workspace.services.pluck(:category))
                   .compact_blank
                   .tally
                   .sort_by { |_category, count| -count }

      if categories.empty?
        return Outcome.insufficient_data(
          reason: "Add products or services and Prachar can work out your content themes."
        )
      end

      Outcome.analysed(
        source: "catalog",
        categories: categories.map { |category, count| { name: category, items: count } }
      )
    end
  end
end
