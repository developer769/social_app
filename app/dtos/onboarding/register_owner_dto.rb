module Onboarding
  class RegisterOwnerDto < ApplicationDto
    attribute :name, :email, :password, :business_name

    def initialize(name:, email:, password:, business_name:)
      @name = name.to_s.strip
      @email = email.to_s.strip.downcase
      @password = password.to_s
      @business_name = business_name.to_s.strip
      freeze
    end
  end
end
