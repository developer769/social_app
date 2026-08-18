# One text-like form control: label, control, hint and inline error, wired
# together with aria-describedby so screen readers announce them (spec 33).
class FormFieldComponent < ApplicationComponent
  def initialize(form:, attribute:, label:, type: :text_field, hint: nil, required: false,
                 placeholder: nil, autocomplete: nil, maxlength: nil, prefix: nil, **input_options)
    @form = form
    @attribute = attribute
    @label = label
    @type = type
    @hint = hint
    @required = required
    @placeholder = placeholder
    @autocomplete = autocomplete
    @maxlength = maxlength
    @prefix = prefix
    @input_options = input_options
  end

  attr_reader :form, :attribute, :label, :type, :hint, :required, :prefix

  def errors
    form.object.respond_to?(:errors) ? Array(form.object.errors[attribute]) : []
  end

  def invalid? = errors.any?

  def hint_id = "#{field_id}-hint"
  def error_id = "#{field_id}-error"

  def field_id
    "#{form.object_name}_#{attribute}".parameterize
  end

  def described_by
    [ (hint_id if hint.present?), (error_id if invalid?) ].compact.presence&.join(" ")
  end

  def input_options
    @input_options.merge(
      required: required,
      placeholder: @placeholder,
      autocomplete: @autocomplete,
      maxlength: @maxlength,
      aria: { describedby: described_by, invalid: (invalid? ? "true" : nil) },
      class: input_classes
    ).compact
  end

  def input_classes
    merge_classes(
      "h-11 w-full rounded-control border bg-background text-sm text-heading",
      "placeholder:text-muted focus:outline-none",
      prefix.present? ? "pl-9 pr-3.5" : "px-3.5",
      invalid? ? "border-danger" : "border-border focus:border-border-strong"
    )
  end
end
