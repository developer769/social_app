# One text-like form control: label, control, hint and inline error, wired
# together with aria-describedby so screen readers announce them (spec 33).
class FormFieldComponent < ApplicationComponent
  def initialize(form:, attribute:, label:, type: :text_field, hint: nil, required: false,
                 placeholder: nil, autocomplete: nil, maxlength: nil, prefix: nil,
                 prefix_size: :symbol, **input_options)
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
    @prefix_size = prefix_size
    @input_options = input_options
  end

  attr_reader :form, :attribute, :label, :type, :hint, :required, :prefix, :prefix_size

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

  # A currency symbol needs a narrow gutter; a scheme like "https://" needs a
  # wide one. Both are fixed classes so Tailwind can see them.
  # Spoken to screen readers in place of the visual prefix.
  PREFIX_DESCRIPTIONS = {
    "+91" => "Indian mobile number, country code plus 91",
    "https://" => "Web address, starting https colon slash slash",
    "₹" => "Amount in rupees"
  }.freeze

  def prefix_description
    PREFIX_DESCRIPTIONS.fetch(prefix.to_s) { "Starts with #{prefix}" }
  end

  def prefix_width_class = (prefix_size == :text) ? "w-[4.25rem]" : "w-9"
  def input_padding_class = (prefix_size == :text) ? "pl-[4.25rem] pr-3.5" : "pl-9 pr-3.5"

  def input_classes
    merge_classes(
      "h-11 w-full rounded-control border bg-background text-sm text-heading",
      "placeholder:text-muted focus:outline-none",
      prefix.present? ? input_padding_class : "px-3.5",
      invalid? ? "border-danger" : "border-border focus:border-border-strong"
    )
  end
end
