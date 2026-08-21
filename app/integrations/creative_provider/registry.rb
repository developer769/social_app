module CreativeProvider
  # Which provider generates creatives.
  #
  # Empty of real providers today, so everything routes to the mock and every
  # asset is a watermarked sample. A real provider lands by adding one entry
  # here; FeatureAvailability reads any_real? to decide whether the product may
  # describe generation as available at all.
  module Registry
    REAL_ADAPTERS = {}.freeze

    module_function

    def default
      REAL_ADAPTERS.values.first&.new || MockAdapter.new
    end

    def for(key)
      klass = REAL_ADAPTERS[key.to_s]
      return klass.new if klass
      return MockAdapter.new if key.to_s == "mock"

      raise ArgumentError, "unknown creative provider: #{key}"
    end

    def any_real? = REAL_ADAPTERS.any?
    def mocked? = !any_real?
  end
end
