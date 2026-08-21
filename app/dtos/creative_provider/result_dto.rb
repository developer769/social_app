module CreativeProvider
  class ResultDto < ApplicationDto
    attribute :io, :filename, :content_type, :width, :height, :sample, :metadata

    def initialize(io:, filename:, content_type:, width: nil, height: nil, sample: true, metadata: {})
      @io = io
      @filename = filename
      @content_type = content_type
      @width = width
      @height = height
      @sample = sample
      @metadata = metadata.freeze
      freeze
    end

    def sample? = sample
  end
end
