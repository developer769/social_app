module Generation
  # Assembles what the generator is told, from the workspace's own data.
  #
  # The owner's free-text note is passed through as its own field and never
  # concatenated into instructions that could change the model, the size or the
  # variant count. Those come from code, so a hostile note cannot reach them.
  class BriefBuilder
    def initialize(request:)
      @request = request
    end

    def call
      workspace = @request.workspace
      template = @request.template
      subject = @request.subject

      CreativeProvider::BriefDto.new(
        workspace_name: workspace.name,
        media_format: @request.media_format,
        aspect_ratio: template&.aspect_ratio || "4:5",
        subject_name: subject&.name,
        subject_description: subject.try(:description),
        template_name: template&.name,
        style_tags: template&.style_tags || [],
        prompt_instructions: template&.prompt_instructions,
        instructions: @request.instructions,
        brand_tones: workspace.brand_tones.map(&:label),
        reference_image: reference_image(template)
      )
    end

    private

    def reference_image(template)
      return if template.blank? || !template.preview.attached?

      template.preview.download
    end
  end
end
