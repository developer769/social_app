# The company facts that appear in the privacy policy and terms.
#
# Read from config/legal.yml rather than written into the templates, because
# they are the same facts in several places and a policy that contradicts
# itself is worse than one that is merely incomplete.
module LegalDetails
  PLACEHOLDER = "CHANGE_ME".freeze

  module_function

  def all
    @all ||= Rails.application.config_for(:legal).to_h.with_indifferent_access
  end

  def fetch(key) = all[key]

  def missing? = all.values.any? { |value| value.to_s.include?(PLACEHOLDER) }

  # Which facts are still unset. Shown on the page itself in development, so a
  # placeholder cannot quietly reach a document somebody relies on.
  def missing_keys
    all.select { |_, value| value.to_s.include?(PLACEHOLDER) }.keys
  end

  def effective_on
    Date.parse(all[:effective_date].to_s)
  rescue ArgumentError, TypeError
    Date.current
  end
end
