module CreativeProvider
  # The interface every generation provider implements. Returns a normalised
  # result or raises PermanentError / TransientError, so callers never branch on
  # a provider's own error shapes.
  class Adapter
    def key = self.class.name.demodulize.underscore
    def capabilities = raise(NotImplementedError, "#{self.class} must declare capabilities")

    # => CreativeProvider::ResultDto
    def generate(brief:, variant_index:)
      raise NotImplementedError, "#{self.class} must implement #generate"
    end

    # Every asset a provider returns while no real one is contracted is a
    # sample: watermarked, and refused by publishing.
    def sample? = true
  end
end
