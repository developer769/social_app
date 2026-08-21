module CreativeProvider
  # Everything the generator is told, assembled from the workspace's own data.
  #
  # The owner's free-text note occupies its own field and only ever describes
  # the scene. It cannot change the model, the size, the variant count or the
  # safety settings, because those are set from code and never from the brief.
  class BriefDto < ApplicationDto
    attribute :workspace_name, :subject_name, :subject_description, :template_name,
              :style_tags, :prompt_instructions, :instructions, :brand_tones,
              :media_format, :aspect_ratio, :reference_image, :seed

    def initialize(workspace_name:, media_format: "image", aspect_ratio: "4:5",
                   subject_name: nil, subject_description: nil, template_name: nil,
                   style_tags: [], prompt_instructions: nil, instructions: nil,
                   brand_tones: [], reference_image: nil, seed: nil)
      @workspace_name = workspace_name
      @media_format = media_format
      @aspect_ratio = aspect_ratio
      @subject_name = subject_name
      @subject_description = subject_description
      @template_name = template_name
      @style_tags = Array(style_tags).freeze
      @prompt_instructions = prompt_instructions
      # Truncated at the boundary: a brief is a sentence, not a payload.
      @instructions = instructions.to_s.strip.first(200).presence
      @brand_tones = Array(brand_tones).freeze
      @reference_image = reference_image
      @seed = seed
      freeze
    end

    def headline = subject_name.presence || template_name.presence || workspace_name
  end
end
