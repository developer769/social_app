module Catalog
  class ServiceDto < ApplicationDto
    attribute :name, :category, :starting_price_minor, :currency, :duration_min_days,
              :duration_max_days, :description, :booking_url, :availability_status,
              :featured, :cover_image

    def initialize(name: nil, category: nil, starting_price: nil, currency: "INR",
                   duration_min_days: nil, duration_max_days: nil, description: nil,
                   booking_url: nil, availability_status: "available", featured: false,
                   cover_image: nil)
      @name = name.to_s.strip.presence
      @category = category.to_s.strip.presence
      @currency = currency.to_s.upcase.presence || "INR"
      @starting_price_minor = Money.from_major(sanitise_amount(starting_price), currency: @currency)&.minor_units
      @duration_min_days = positive_integer(duration_min_days)
      @duration_max_days = positive_integer(duration_max_days)
      @description = description.to_s.strip.presence
      @booking_url = CatalogUrl.normalise(booking_url)
      @availability_status = Service::AVAILABILITY_STATUSES.include?(availability_status.to_s) ? availability_status.to_s : "available"
      @featured = ActiveModel::Type::Boolean.new.cast(featured) || false
      @cover_image = cover_image
      freeze
    end

    def to_attributes
      {
        name: name, category: category, starting_price_minor: starting_price_minor,
        currency: currency, duration_min_days: duration_min_days,
        duration_max_days: duration_max_days, description: description,
        booking_url: booking_url, availability_status: availability_status, featured: featured
      }
    end

    private

    def sanitise_amount(value) = value.to_s.gsub(/[^\d.]/, "").presence

    def positive_integer(value)
      number = value.to_s.strip
      return if number.blank?

      parsed = Integer(number, exception: false)
      (parsed && parsed.positive?) ? parsed : nil
    end
  end
end
