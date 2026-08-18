# The footer that carries the primary action on wizard screens. Sticks to the
# bottom on small screens so the action stays reachable (spec 19).
class StickyActionFooterComponent < ApplicationComponent
  renders_one :secondary
  renders_one :primary
  renders_one :note
end
