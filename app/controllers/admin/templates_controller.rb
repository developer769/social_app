module Admin
  class TemplatesController < BaseController
    before_action :set_template, only: %i[edit update publish unpublish retire]

    def index
      @scope = params[:scope].presence_in(%w[published drafts retired]) || "published"
      @templates = filtered_scope.includes(:published_by).order(updated_at: :desc)
      @counts = {
        "published" => Template.published.count,
        "drafts" => Template.where(draft: true).count,
        "retired" => Template.where.not(retired_at: nil).count
      }
    end

    def new
      # New styles start as drafts: uploading is not publishing, and a
      # half-finished row must never reach a customer's gallery.
      @template = Template.new(draft: true, media_format: "image", aspect_ratio: "4:5")
    end

    def create
      @template = Template.new(template_params)
      @template.draft = true
      @template.source = "curated"
      @template.first_seen_at = Time.current

      if @template.save
        record_staff_event("template.created", auditable: @template, metadata: { name: @template.name })
        redirect_to edit_admin_template_path(@template), notice: "Draft saved. Publish it when it is ready."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @template.update(template_params)
        record_staff_event("template.updated", auditable: @template, metadata: { name: @template.name })
        redirect_to edit_admin_template_path(@template), notice: "Saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def publish
      @template.publish!(staff_user: current_staff_user)
      record_staff_event("template.published", auditable: @template, metadata: { name: @template.name })
      redirect_to edit_admin_template_path(@template),
        notice: "#{@template.name} is now live in every workspace's gallery."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_content
    end

    def unpublish
      @template.unpublish!
      record_staff_event("template.unpublished", auditable: @template, metadata: { name: @template.name })
      redirect_to edit_admin_template_path(@template), notice: "Back to draft. Customers can no longer see it."
    end

    def retire
      @template.retire!
      record_staff_event("template.retired", auditable: @template, metadata: { name: @template.name })
      redirect_to admin_templates_path(scope: "retired"),
        notice: "#{@template.name} is retired. Posts already made with it are unaffected."
    end

    private

    def set_template = @template = Template.find(params[:id])

    def filtered_scope
      case @scope
      when "drafts" then Template.where(draft: true)
      when "retired" then Template.where.not(retired_at: nil)
      else Template.published
      end
    end

    def template_params
      permitted = params.expect(
        template: [ :name, :slug, :description, :media_format, :content_category, :aspect_ratio,
                    :duration_seconds, :industry, :premium, :position, :prompt_instructions,
                    :preview, :media, { style_tags: [], supported_platforms: [] } ]
      )

      # Typed as a comma-separated list in the form; stored as an array.
      permitted[:style_tags] = split_list(params.dig(:template, :style_tags_text)) if params.dig(:template, :style_tags_text)
      permitted[:slug] = permitted[:slug].presence || generated_slug(permitted)
      permitted
    end

    def split_list(value) = value.to_s.split(",").map(&:strip).compact_blank

    def generated_slug(attributes)
      base = attributes[:name].to_s.parameterize
      suffix = attributes[:media_format] == "video" ? "video" : "photo"
      "#{base}-#{suffix}"
    end
  end
end
