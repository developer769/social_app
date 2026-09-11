module Onboarding
  class RegisterOwnerDto < ApplicationDto
    attribute :name, :email, :password, :password_confirmation, :business_name, :account_type

    def initialize(name:, email:, password:, business_name:, password_confirmation: nil, account_type: nil)
      @name = name.to_s.strip
      @email = email.to_s.strip.downcase
      @password = password.to_s
      # Left nil when the form did not send one: has_secure_password only
      # compares the two when a confirmation is present, so nil means "not
      # asked" while "" would mean "asked, and left blank" -- which must fail.
      @password_confirmation = password_confirmation.nil? ? nil : password_confirmation.to_s
      @business_name = business_name.to_s.strip
      # Anything unrecognised falls back to business rather than reaching the
      # database and failing a check constraint. A sign-up form is the wrong
      # place to surface a 500 over a value nobody typed by hand.
      @account_type = Workspace::ACCOUNT_TYPES.include?(account_type.to_s) ? account_type.to_s : "business"
      freeze
    end

    def influencer? = @account_type == "influencer"
  end
end
