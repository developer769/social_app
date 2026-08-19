module Analysis
  # One analyzer per task. Each is given the workspace and returns an Outcome;
  # none of them writes to the database, so they stay easy to test and safe to
  # re-run.
  class Analyzer
    def self.call(workspace:) = new(workspace: workspace).call

    def initialize(workspace:)
      @workspace = workspace
    end

    attr_reader :workspace

    def call = raise(NotImplementedError, "#{self.class} must implement #call")

    private

    def connected_accounts
      @connected_accounts ||= workspace.social_accounts.connected.to_a
    end

    # Mock connections carry no real history, so anything that depends on past
    # performance must not pretend otherwise.
    def real_performance_data?
      connected_accounts.any? { |account| !account.mocked? }
    end
  end
end
