module AuthenticationHelpers
  def sign_in(user)
    post login_path, params: { email: user.email, password: "correct-horse-battery" }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
