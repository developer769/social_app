class ApplicationComponent < ViewComponent::Base
  # Joins Tailwind class lists, letting callers append without losing the
  # component's own styling.
  def merge_classes(*lists)
    lists.flatten.compact_blank.join(" ")
  end
end
