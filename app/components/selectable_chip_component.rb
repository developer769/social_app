# A checkbox styled as a chip, used for goals and brand tones. State is carried
# by the checkbox itself, so it works without JavaScript and reads correctly to
# screen readers; the tick is not the only indicator (spec 33).
class SelectableChipComponent < ApplicationComponent
  def initialize(name:, value:, label:, checked: false, description: nil, disabled: false)
    @name = name
    @value = value
    @label = label
    @checked = checked
    @description = description
    @disabled = disabled
  end

  attr_reader :name, :value, :label, :checked, :description, :disabled

  def input_id = "#{name}-#{value}".parameterize
end
