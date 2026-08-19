# The starting template catalogue.
#
# The preview images in db/seeds/templates are crops of the supplied design
# deck. They are DEVELOPMENT FIXTURES so the gallery can be reviewed against the
# design; production artwork is supplied by the trend source, and these are not
# licensed for it.
#
# trend_score is deliberately left NULL on every row. No source has supplied a
# real popularity signal yet, and a made-up score would turn the gallery's
# ordering into a claim the product cannot support (spec 27). The gallery falls
# back to curated order and says so.
template_fixtures = [
  # ---- Photos --------------------------------------------------------------
  { file: "photo-01.jpg", name: "Weekend Indulgence", category: "product_showcase",
    description: "A rich, dark hero shot with an indulgent headline. Works well for a weekend push on a signature item.",
    style: %w[decadent rich premium], premium: false },
  { file: "photo-02.jpg", name: "Pure Chocolate Bliss", category: "product_showcase",
    description: "Clean editorial layout with the product centre stage and a short three-word promise.",
    style: %w[editorial clean warm], premium: false },
  { file: "photo-03.jpg", name: "Bite into Happiness", category: "product_showcase",
    description: "Bright, airy styling with a script accent. Suits stacked or layered items.",
    style: %w[bright airy playful], premium: false },
  { file: "photo-04.jpg", name: "Eid Mubarak", category: "festive",
    description: "A festive greeting frame with lanterns and an arch motif, for Eid wishes alongside your range.",
    style: %w[festive ornate warm], premium: true },
  { file: "photo-05.jpg", name: "Freshly Baked Cookies", category: "new_launch",
    description: "Bold sans headline over a soft blue ground. Good for announcing something just out of the oven.",
    style: %w[bold fresh simple], premium: false },
  { file: "photo-06.jpg", name: "Celebrate Every Moment", category: "festive",
    description: "Soft celebratory styling with a script headline, for birthdays and small occasions.",
    style: %w[celebratory soft romantic], premium: false },
  { file: "photo-07.jpg", name: "But First, Coffee", category: "menu",
    description: "Calm, muted styling for a drinks or pairing menu item.",
    style: %w[calm muted cosy], premium: false },
  { file: "photo-08.jpg", name: "Red Velvet Delight", category: "product_showcase",
    description: "Deep plum ground with a cut-slice hero. Strong contrast for a signature cake.",
    style: %w[dramatic rich premium], premium: true },
  { file: "photo-09.jpg", name: "Made with Love", category: "product_showcase",
    description: "Gifting-led composition with ribbon and card. Suits hampers and packaged orders.",
    style: %w[gifting elegant understated], premium: false },
  { file: "photo-10.jpg", name: "Cupcakes That Steal Hearts", category: "product_showcase",
    description: "Playful script over a pastel ground, for smaller items sold by the box.",
    style: %w[playful pastel sweet], premium: false },

  # ---- Videos --------------------------------------------------------------
  { file: "video-01.jpg", name: "Freshly Baked Happiness", category: "reels_style", duration: 15,
    description: "Short vertical reel opening on the finished product, with a script title card.",
    style: %w[warm inviting simple], premium: false },
  { file: "video-02.jpg", name: "Behind the Scenes", category: "behind_the_scenes", duration: 20,
    description: "A hands-at-work sequence showing how an item is finished. Builds trust quickly.",
    style: %w[authentic close-up craft], premium: false },
  { file: "video-03.jpg", name: "Chocolate Fudge Cake", category: "product_showcase", duration: 18,
    description: "Slow product turn with a three-word promise. Built around one hero item.",
    style: %w[decadent rich premium], premium: true },
  { file: "video-04.jpg", name: "Limited Time Offer", category: "offer", duration: 16,
    description: "Offer-led reel with the discount stated in the first second.",
    style: %w[urgent bold promotional], premium: false },
  { file: "video-05.jpg", name: "Reel Time", category: "reels_style", duration: 22,
    description: "Fast-cut montage across several items. Good for a range rather than one product.",
    style: %w[energetic fast varied], premium: false },
  { file: "video-06.jpg", name: "How It's Made", category: "behind_the_scenes", duration: 15,
    description: "Process shot from raw ingredient to finished item.",
    style: %w[process craft honest], premium: false },
  { file: "video-07.jpg", name: "New Arrivals", category: "new_launch", duration: 17,
    description: "Announcement reel for something new, ending on a call to visit or order.",
    style: %w[fresh inviting bright], premium: false },
  { file: "video-08.jpg", name: "Customer Love", category: "testimonials", duration: 14,
    description: "A thank-you reel framed around customer appreciation.",
    style: %w[grateful warm personal], premium: false },
  { file: "video-09.jpg", name: "Perfect Pair", category: "menu", duration: 19,
    description: "Pairing reel showing two items together, for combos and set menus.",
    style: %w[cosy pairing calm], premium: false },
  { file: "video-10.jpg", name: "Bakers at Work", category: "behind_the_scenes", duration: 21,
    description: "Team-at-work sequence emphasising care and detail.",
    style: %w[craft team authentic], premium: true },
  { file: "video-11.jpg", name: "Red Velvet Delight", category: "product_showcase", duration: 18,
    description: "Single-item hero reel with a bold colour ground.",
    style: %w[dramatic rich classic], premium: false },
  { file: "video-12.jpg", name: "Tips & Tricks", category: "tips", duration: 16,
    description: "Short educational reel sharing one useful tip. Good for reach beyond existing customers.",
    style: %w[educational helpful clear], premium: false }
].freeze

fixtures_dir = Rails.root.join("db/seeds/templates")

template_fixtures.each_with_index do |fixture, index|
  video = fixture[:duration].present?
  # The same name can legitimately exist as both a photo and a video
  # ("Red Velvet Delight"), so the format is part of the identity.
  slug = "#{fixture[:name].parameterize}-#{video ? 'video' : 'photo'}"

  template = Template.find_or_initialize_by(slug: slug)
  template.assign_attributes(
    name: fixture[:name],
    description: fixture[:description],
    media_format: video ? "video" : "image",
    content_category: fixture[:category],
    aspect_ratio: video ? "9:16" : "4:5",
    duration_seconds: fixture[:duration],
    style_tags: fixture[:style],
    supported_platforms: video ? %w[instagram facebook youtube tiktok] : %w[instagram facebook linkedin google_business x],
    prompt_instructions: "#{fixture[:name]}: #{fixture[:description]} Style: #{fixture[:style].join(', ')}.",
    premium: fixture[:premium],
    active: true,
    source: "curated",
    first_seen_at: template.first_seen_at || Time.current,
    last_refreshed_at: Time.current,
    position: index + 1
  )
  template.save!

  path = fixtures_dir.join(fixture[:file])
  if path.exist? && !template.preview.attached?
    template.preview.attach(io: File.open(path), filename: fixture[:file], content_type: "image/jpeg")
  end
end

unless Rails.env.test?
  puts "Seeded #{Template.count} templates " \
       "(#{Template.photos.count} photos, #{Template.videos.count} videos)"
end
