require "rails_helper"

RSpec.describe CreativeProvider::MockAdapter do
  subject(:adapter) { described_class.new }

  def brief(format: "image", headline: "Chocolate Truffle Cake", reference: nil)
    CreativeProvider::BriefDto.new(
      workspace_name: "Anaya Bakes", media_format: format, aspect_ratio: "4:5",
      subject_name: headline, template_name: "Weekend Indulgence",
      style_tags: %w[warm], brand_tones: [ "Warm" ], reference_image: reference
    )
  end

  def preview_bytes = File.binread(Rails.root.join("db/seeds/templates/photo-01.jpg"))

  # The registry stores this string on every request. If the two ever disagree,
  # RunOutputJob raises "unknown creative provider" on the worker, where nobody
  # is looking.
  it "answers to the key the registry hands back" do
    expect(adapter.key).to eq("mock")
    expect(CreativeProvider::Registry.for(adapter.key)).to be_a(described_class)
  end

  it "produces a real JPEG at the requested aspect ratio" do
    result = adapter.generate(brief: brief, variant_index: 0)

    expect(result.content_type).to eq("image/jpeg")
    expect([ result.width, result.height ]).to eq([ 1080, 1350 ])
    expect(result.io.size).to be > 1_000
  end

  # Three identical pictures are not a choice. Variants must actually differ.
  it "makes each variant visibly different" do
    reference = preview_bytes
    bytes = 3.times.map { |i| adapter.generate(brief: brief(reference: reference), variant_index: i).io.read }

    expect(bytes.uniq.size).to eq(3)
  end

  it "is deterministic, so the same variant always comes back the same" do
    reference = preview_bytes
    first = adapter.generate(brief: brief(reference: reference), variant_index: 1).io.read
    second = adapter.generate(brief: brief(reference: reference), variant_index: 1).io.read

    expect(first).to eq(second)
  end

  # Spec 27. A sample that is not flagged as a sample can be mistaken for a
  # publishable creative, which is the one mistake this must never make.
  it "marks everything it returns as a watermarked sample" do
    result = adapter.generate(brief: brief, variant_index: 0)

    expect(result.sample?).to be(true)
    expect(result.metadata).to include(watermarked: true)
  end

  # Spec 30. Nothing connected can make video, so it says so instead of
  # returning a still and calling it one.
  it "refuses video permanently rather than pretending" do
    expect { adapter.generate(brief: brief(format: "video"), variant_index: 0) }
      .to raise_error(CreativeProvider::PermanentError, /not available yet/)
  end

  it "still produces a picture when the style has no preview to work from" do
    expect(adapter.generate(brief: brief(reference: nil), variant_index: 0).io.size).to be > 1_000
  end

  it "does not claim to make video" do
    expect(adapter.capabilities.generate_video?).to be(false)
  end
end
