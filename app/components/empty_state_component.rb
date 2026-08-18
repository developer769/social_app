# The honest "there is nothing here yet" state (spec 20). Says what is missing
# and what to do about it, rather than showing placeholder data.
class EmptyStateComponent < ApplicationComponent
  renders_one :action

  def initialize(title:, body: nil)
    @title = title
    @body = body
  end

  attr_reader :title, :body
end
