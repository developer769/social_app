class SelectFieldComponent < ApplicationComponent
  def initialize(form:, attribute:, label:, choices:, hint: nil, required: false, include_blank: nil)
    @form = form
    @attribute = attribute
    @label = label
    @choices = choices
    @hint = hint
    @required = required
    @include_blank = include_blank
  end

  attr_reader :form, :attribute, :label, :choices, :hint, :required, :include_blank

  def errors
    form.object.respond_to?(:errors) ? Array(form.object.errors[attribute]) : []
  end

  def invalid? = errors.any?
  def hint_id = "#{field_id}-hint"
  def error_id = "#{field_id}-error"
  def field_id = "#{form.object_name}_#{attribute}".parameterize

  def described_by
    [ (hint_id if hint.present?), (error_id if invalid?) ].compact.presence&.join(" ")
  end

  def select_classes
    merge_classes(
      "h-11 w-full appearance-none rounded-control border bg-background px-3.5 pr-10 text-sm text-heading",
      "focus:outline-none",
      invalid? ? "border-danger" : "border-border focus:border-border-strong"
    )
  end
end
