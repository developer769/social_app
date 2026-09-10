module SocialProvider
  # Resolves a provider key to the adapter that should serve it.
  #
  # Every provider is mocked today. Real adapters land one at a time, each
  # after its live API documentation has been re-checked (spec 35, phase 6),
  # by adding an entry here -- nothing else in the application changes.
  module Registry
    REAL_ADAPTERS = {}.freeze

    module_function

    # `credentials` is only meaningful to a real adapter, and only during the
    # window between exchanging an authorization code and having an account row
    # to hang it on. The mock ignores it.
    def for(provider_key, workspace: nil, account: nil, credentials: nil)
      key = provider_key.to_s
      raise ArgumentError, "unknown provider: #{key}" unless Catalog.keys.include?(key)

      adapter_class = REAL_ADAPTERS[key]
      return adapter_class.new(account: account, credentials: credentials) if adapter_class

      MockAdapter.new(key: key, workspace: workspace || account&.workspace, account: account)
    end

    def mocked?(provider_key) = !REAL_ADAPTERS.key?(provider_key.to_s)

    def any_real? = REAL_ADAPTERS.any?
  end
end
