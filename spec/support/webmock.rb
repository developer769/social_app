require "webmock/rspec"

# Every outbound connection is blocked. A spec that reaches a live social or AI
# provider fails loudly instead of silently passing (spec 34).
WebMock.disable_net_connect!(allow_localhost: true)
