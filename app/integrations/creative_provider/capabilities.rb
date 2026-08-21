module CreativeProvider
  # What a generation provider can actually do. Read by the interface, so it
  # never offers something the provider would refuse.
  class Capabilities
    FLAGS = %i[generate_image generate_video reference_image style_prompt].freeze

    attr_reader :limits

    def initialize(supports: [], limits: {})
      @supports = supports.map(&:to_sym).to_set
      @limits = limits.freeze
      unknown = @supports - FLAGS.to_set
      raise ArgumentError, "unknown capability flags: #{unknown.to_a.join(', ')}" if unknown.any?

      freeze
    end

    FLAGS.each { |flag| define_method(:"#{flag}?") { @supports.include?(flag) } }

    def supports?(flag) = @supports.include?(flag.to_sym)
    def max_variants = limits.fetch(:max_variants, 1)
    def max_video_seconds = limits[:max_video_seconds]
    def typical_seconds = limits[:typical_seconds]
  end
end
