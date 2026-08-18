module Catalog
  class ProductDto < ApplicationDto
    attribute :name, :category, :price_minor, :currency, :price_is_starting_from,
              :description, :url, :availability_status, :stock_status, :featured, :image

    def initialize(name: nil, category: nil, price: nil, currency: "INR",
                   price_is_starting_from: false, description: nil, url: nil,
                   availability_status: "available", stock_status: "in_stock",
                   featured: false, image: nil)
      @name = name.to_s.strip.presence
      @category = category.to_s.strip.presence
      @currency = currency.to_s.upcase.presence || "INR"
      @price_minor = Money.from_major(sanitise_amount(price), currency: @currency)&.minor_units
      @price_is_starting_from = ActiveModel::Type::Boolean.new.cast(price_is_starting_from) || false
      @description = description.to_s.strip.presence
      @url = CatalogUrl.normalise(url)
      @availability_status = coerce(availability_status, Product::AVAILABILITY_STATUSES, "available")
      @stock_status = coerce(stock_status, Product::STOCK_STATUSES, "in_stock")
      @featured = ActiveModel::Type::Boolean.new.cast(featured) || false
      @image = image
      freeze
    end

    def to_attributes
      {
        name: name, category: category, price_minor: price_minor, currency: currency,
        price_is_starting_from: price_is_starting_from, description: description, url: url,
        availability_status: availability_status, stock_status: stock_status, featured: featured
      }
    end

    private

    # Owners type "1,549" or "Rs 1549"; keep the number.
    def sanitise_amount(value)
      cleaned = value.to_s.gsub(/[^\d.]/, "")
      cleaned.presence
    end

    def coerce(value, allowed, fallback)
      allowed.include?(value.to_s) ? value.to_s : fallback
    end
  end
end
