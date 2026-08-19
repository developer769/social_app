module ConnectionsHelper
  # Describes what a platform actually accepts, read from its capabilities
  # rather than assumed, so the card never promises something the API refuses.
  def publishable_formats(capabilities)
    formats = []
    formats << "Images" if capabilities.publish_image?
    formats << "Video" if capabilities.publish_video?
    formats << "Text" if capabilities.publish_text?

    return "Nothing yet" if formats.empty?

    formats.to_sentence
  end
end
