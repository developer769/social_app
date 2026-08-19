module TrendSource
  # A source of evidence about what is currently working.
  #
  # A source never returns templates. It returns SIGNALS about content
  # categories, which the refresh maps onto Prachar's own catalogue. This is the
  # important boundary: trend data tells us which STYLE is working, it does not
  # give us other people's images and videos to hand out. Those belong to the
  # creators who made them.
  class Adapter
    def key = self.class.name.demodulize.underscore

    # True only when this source can actually be called right now. A source
    # missing its credentials reports unavailable rather than quietly returning
    # nothing, so a silent feed is visible instead of looking like "no trends".
    def available? = false

    # What the label may say when this source supplied the ordering. The
    # gallery renders this verbatim, so it can never overstate the evidence.
    def attribution = "Curated by Prachar"

    # => Array<TrendSignalDto>
    def fetch_signals
      raise NotImplementedError, "#{self.class} must implement #fetch_signals"
    end

    private

    def unavailable!(reason)
      raise SocialProvider::PermanentError.new(reason, code: "source_unavailable")
    end
  end
end
