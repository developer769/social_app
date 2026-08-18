# Owners type "anayabakes.com/cakes", not "https://anayabakes.com/cakes".
# Adding the scheme keeps the stored value a real, clickable address; without
# it the browser would treat the value as a path inside Prachar.
module CatalogUrl
  module_function

  def normalise(value)
    trimmed = value.to_s.strip
    return if trimmed.blank?
    return trimmed if trimmed.match?(%r{\Ahttps?://}i)

    "https://#{trimmed}"
  end
end
