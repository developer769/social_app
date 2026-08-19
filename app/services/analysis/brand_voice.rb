module Analysis
  # Reads the tones the owner chose. Once real post history exists this will
  # also read published captions, but it will never guess a voice from nothing.
  class BrandVoice < Analyzer
    def call
      tones = workspace.brand_tones.map(&:label)

      if tones.empty?
        return Outcome.insufficient_data(
          reason: "Choose a brand tone in Business Setup so captions sound like you."
        )
      end

      Outcome.analysed(source: "stated_preference", tones: tones,
                       note: "Based on the tone you chose. Prachar will refine this from your published captions.")
    end
  end
end
