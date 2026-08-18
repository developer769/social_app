# Onboarding progress. Renders real position, not a decorative animation, and
# announces itself to assistive technology.
class WizardProgressComponent < ApplicationComponent
  def initialize(steps:, current_step:)
    @steps = steps
    @current_step = current_step.to_s
  end

  attr_reader :steps, :current_step

  def current_index
    steps.index { |step| step[:key].to_s == current_step } || 0
  end

  def position = current_index + 1
  def total = steps.size
  def label = "Step #{position} of #{total}"

  def state_for(index)
    return :current if index == current_index
    return :complete if index < current_index

    :upcoming
  end

  def bar_classes(index)
    base = "h-1.5 flex-1 rounded-pill"

    case state_for(index)
    when :complete then "#{base} bg-primary"
    when :current then "#{base} bg-primary"
    else "#{base} bg-border"
    end
  end
end
