module GalleryHelper
  def gallery_empty_title(search)
    noun = search.photos? ? "photo styles" : "video styles"

    return "No #{noun} match \"#{search.query}\"" if search.query.present?
    return "No #{noun} in this category yet" if search.category.present?

    "No #{noun} published yet"
  end

  def gallery_empty_body(search)
    return "Try a different word, or clear the filters to see everything." if search.query.present?
    return "Other categories still have styles. Clear the filter to see them." if search.category.present?

    "Prachar publishes new styles regularly. Check back shortly."
  end

  # What the template counters genuinely are: uses inside Prachar, counted from
  # real generations. Below a floor the number is meaningless as social proof,
  # so the reason is stated rather than showing a bare "0" (spec 27).
  SOCIAL_PROOF_FLOOR = 25

  def template_usage_note(template)
    count = template.generations_count.to_i

    return "New style" if count.zero?
    return "Recently added" if count < SOCIAL_PROOF_FLOOR

    "Chosen by #{number_with_delimiter(count)} businesses"
  end
end
