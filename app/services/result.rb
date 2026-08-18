# The single return contract for every service and command (spec 14).
class Result
  attr_reader :value, :error

  def self.success(value = nil) = new(success: true, value: value)
  def self.failure(error) = new(success: false, error: error)

  def initialize(success:, value: nil, error: nil)
    @success = success
    @value = value
    @error = error
    freeze
  end

  def success? = @success
  def failure? = !@success
end
