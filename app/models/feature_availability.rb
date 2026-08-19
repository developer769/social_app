# Whether a capability is actually delivered right now, as opposed to designed.
#
# The plan screen listed "Unlimited AI generations" while no generation provider
# existed anywhere in the application. A pricing page attached to a trial button
# is the worst place to describe something the product cannot do, so what is
# sold is derived from what is wired up rather than written by hand.
module FeatureAvailability
  # Entitlement keys whose delivery depends on a provider that must be
  # registered before the feature can honestly be offered.
  PROVIDER_BACKED = {
    "ai_generations_per_month" => :creative_generation
  }.freeze

  module_function

  def creative_generation_live?
    return false unless defined?(CreativeProvider::Registry)

    CreativeProvider::Registry.any_real?
  end

  def live?(entitlement_key)
    capability = PROVIDER_BACKED[entitlement_key.to_s]
    return true if capability.nil?

    case capability
    when :creative_generation then creative_generation_live?
    else true
    end
  end
end
