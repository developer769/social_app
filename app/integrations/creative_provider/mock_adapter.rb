module CreativeProvider
  # Stands in for a real generation provider until one is contracted.
  #
  # It produces a genuine image rather than a grey box, so the flow can be
  # judged as it will feel: the chosen style's own preview, varied per variant,
  # with the product name set on it. Every result carries a visible
  # PRACHAR SAMPLE watermark and is marked sample: true, because a picture that
  # looks generated but is not must never be mistaken for one that is (spec 27).
  #
  # It is deterministic: the same brief and variant always produce the same
  # image, so development and specs are stable.
  class MockAdapter < Adapter
    # The key stored on a request, so it must match what Registry.for accepts.
    def key = "mock"

    SIZES = { "1:1" => [ 1080, 1080 ], "4:5" => [ 1080, 1350 ],
              "9:16" => [ 1080, 1920 ], "16:9" => [ 1920, 1080 ] }.freeze

    # Deliberately narrower than a real provider: it cannot make video, and
    # saying so keeps the interface honest about what is on offer today.
    def capabilities
      @capabilities ||= Capabilities.new(
        supports: %i[generate_image reference_image style_prompt],
        limits: { max_variants: 3, typical_seconds: 2 }
      )
    end

    def generate(brief:, variant_index:)
      unless capabilities.generate_image?
        raise PermanentError.new("This provider cannot generate images", code: "unsupported")
      end

      if brief.media_format.to_s == "video"
        raise PermanentError.new(
          "Video generation is not available yet. No provider is connected that can make video.",
          code: "video_unsupported"
        )
      end

      width, height = SIZES.fetch(brief.aspect_ratio, SIZES.fetch("4:5"))
      image = compose(brief: brief, variant_index: variant_index, width: width, height: height)

      ResultDto.new(
        io: StringIO.new(image.write_to_buffer(".jpg[Q=82]")),
        filename: "sample-#{brief.headline.parameterize}-#{variant_index + 1}.jpg",
        content_type: "image/jpeg",
        width: width, height: height, sample: true,
        metadata: { provider: "mock", variant: variant_index + 1, watermarked: true }
      )
    rescue Vips::Error => e
      # A drawing failure is ours, not the brief's, and retrying the same input
      # would fail the same way.
      raise PermanentError.new("Could not render a sample: #{e.class}", code: "render_failed")
    end

    private

    def compose(brief:, variant_index:, width:, height:)
      base = background(brief, variant_index, width, height)
      base = overlay_headline(base, brief, width, height)
      watermark(base, width, height)
    end

    # The style's own preview if there is one, framed differently per variant so
    # the three alternatives are visibly distinct.
    #
    # Variation is crop and exposure, never hue: rotating the palette turned
    # chocolate olive-green, and food that looks wrong reads as a broken feature
    # rather than a different option.
    CROPS = %i[centre attention low].freeze

    def background(brief, variant_index, width, height)
      return gradient(variant_index, width, height) if brief.reference_image.blank?

      image = Vips::Image.new_from_buffer(brief.reference_image, "")
      image = image.thumbnail_image(width, height: height,
                                    crop: CROPS[variant_index % CROPS.size])
      image = image.colourspace(:srgb) if image.bands < 3
      image = image.extract_band(0, n: 3) if image.bands > 3

      expose(image, variant_index)
    end

    # A small, deterministic exposure difference, so the variants read as three
    # takes of the same shot rather than three different pictures.
    def expose(image, variant_index)
      return image if variant_index.zero?

      factor = variant_index == 1 ? 1.08 : 0.92
      (image * factor).cast(:uchar).copy(interpretation: :srgb)
    end

    def gradient(variant_index, width, height)
      palette = [ [ 52, 16, 68 ], [ 34, 17, 58 ], [ 72, 23, 92 ] ]
      top = palette[variant_index % palette.size]

      Vips::Image.black(width, height).add(top).cast(:uchar).copy(interpretation: :srgb)
    end

    def overlay_headline(base, brief, width, height)
      # A dark scrim behind the headline, because these backgrounds carry their
      # own artwork and white text on an unknown image is unreadable.
      base = scrim(base, width, height)

      text = Vips::Image.text(
        brief.headline.to_s.first(40),
        width: (width * 0.8).to_i, font: "sans bold #{(width / 16.0).round}", align: :low
      )

      white = text.new_from_image([ 255, 255, 255 ]).copy(interpretation: :srgb)
      label = white.bandjoin(text.cast(:uchar))

      base.composite2(label, :over, x: (width * 0.08).to_i, y: (height * 0.1).to_i)
    rescue Vips::Error
      # Text is a nicety; a sample without a headline is still a usable sample.
      base
    end

    def scrim(base, width, height)
      band = Vips::Image.black(width, (height * 0.26).to_i).copy(interpretation: :srgb)
      shaded = band.bandjoin(Vips::Image.black(width, (height * 0.26).to_i).add(140).cast(:uchar))

      base.composite2(shaded, :over, x: 0, y: 0)
    rescue Vips::Error
      base
    end

    # The part that must never be optional.
    def watermark(base, width, height)
      mark = Vips::Image.text("PRACHAR SAMPLE", font: "sans bold #{(width / 26.0).round}")
      white = mark.new_from_image([ 255, 255, 255 ]).copy(interpretation: :srgb)
      stamped = white.bandjoin((mark * 0.72).cast(:uchar))

      base.composite2(stamped, :over,
                      x: (width - stamped.width - (width * 0.06)).to_i,
                      y: (height - stamped.height - (height * 0.05)).to_i)
    rescue Vips::Error
      # If the watermark cannot be drawn, the sample is not safe to hand back.
      raise PermanentError.new("Could not watermark the sample", code: "watermark_failed")
    end
  end
end
