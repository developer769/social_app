module Ads
  # How ready this workspace is to advertise, and what is still missing.
  #
  # Advertising is the one area where inventing anything would cost real money.
  # There is no forecast here, no estimated reach, no suggested budget and no
  # cost-per-click: every one of those would be a number Prachar cannot know
  # and a business could act on (spec 22).
  #
  # What IS knowable is checked properly: which platforms allow advertising at
  # all, which of them this workspace has connected, and which of the things a
  # platform will ask for are already in place. All of it read from real
  # records.
  class ReadinessQuery
    Check = Struct.new(:key, :label, :detail, :done, :fix_path, :fix_label, keyword_init: true) do
      def done? = done
    end

    PlatformRow = Struct.new(:provider, :name, :connected, :notes, keyword_init: true)

    def initialize(workspace:)
      @workspace = workspace
    end

    # Platforms that publish an advertising API, whether or not this workspace
    # uses them. Named so the absence is specific.
    def advertising_platforms
      SocialProvider::Catalog::ALL.values.select { |definition| definition.capabilities.advertising? }
    end

    def rows
      advertising_platforms.map do |definition|
        account = accounts[definition.key]

        PlatformRow.new(
          provider: definition.key,
          name: definition.name,
          connected: account.present?,
          notes: definition.notes
        )
      end
    end

    def connected_advertising_platforms = rows.select(&:connected)

    # Every check is answered from data this application actually holds. A check
    # it cannot answer is not included rather than guessed at.
    def checks
      [
        Check.new(
          key: :account,
          label: "An account that can advertise",
          detail: connected_advertising_platforms.any? ?
            "#{connected_advertising_platforms.map(&:name).to_sentence} connected." :
            "None of the platforms that allow advertising are connected yet.",
          done: connected_advertising_platforms.any?,
          fix_path: :connections, fix_label: "Connect an account"
        ),
        Check.new(
          key: :profile,
          label: "A complete business profile",
          detail: profile_complete? ?
            "Your business name, category and description are set." :
            "Ad platforms review the business behind an ad. Fill in your profile first.",
          done: profile_complete?,
          fix_path: :business, fix_label: "Complete your profile"
        ),
        Check.new(
          key: :catalog,
          label: "Something to advertise",
          detail: catalog_count.positive? ?
            "#{pluralize_items} in your catalog." :
            "Add what you sell, so an ad has something to point at.",
          done: catalog_count.positive?,
          fix_path: :catalog, fix_label: "Add products"
        ),
        Check.new(
          key: :published,
          label: "A post worth putting money behind",
          detail: published_count.positive? ? published_summary :
            "Nothing has been published yet. Advertising a post you have never run organically is a guess.",
          done: published_count.positive?,
          fix_path: :calendar, fix_label: "See your calendar"
        )
      ]
    end

    def ready_count = checks.count(&:done?)
    def total_checks = checks.size
    def all_ready? = ready_count == total_checks

    # False everywhere today. Advertising needs an adapter that can spend money,
    # and none exists.
    def available? = SocialProvider::Registry.any_real?

    private

    def accounts
      @accounts ||= @workspace.social_accounts.connected.index_by(&:provider)
    end

    def profile
      @profile ||= @workspace.brand_profile
    end

    # The business name lives on the workspace, not the profile.
    def profile_complete?
      @workspace.name.present? && profile.present? &&
        profile.category.present? && profile.about.present?
    end

    def catalog_count
      @catalog_count ||= @workspace.products.active.count + @workspace.services.active.count
    end

    def pluralize_items
      "#{catalog_count} #{'item'.pluralize(catalog_count)}"
    end

    def published_count
      @published_count ||= @workspace.posts.where(status: %w[published partially_published]).count
    end

    def published_summary
      verb = published_count == 1 ? "has" : "have"
      "#{published_count} #{'post'.pluralize(published_count)} #{verb} gone out."
    end
  end
end
