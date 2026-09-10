# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# Zeitwerk derives a constant name from each filename, and without this it
# expects oauth_adapter.rb to define SocialProvider::OauthAdapter. The protocol
# is spelled OAuth everywhere it appears in its own specification, and a
# codebase that writes it Oauth in class names and OAuth in comments is worse
# than one that just tells the inflector.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "OAuth"
end
