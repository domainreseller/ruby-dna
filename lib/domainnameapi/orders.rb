# frozen_string_literal: true

module DomainNameApi
  # One line of an order.
  class OrderProduct < Model
    field :product_code
    field :product_type, ProductType
    field :order_type, OrderType
    field :status, OrderProductStatus
    field :price, :float
    field :price_currency
    field :name
    field :description
    field :additional_data
    field :period, :integer
  end

  # An order and its lines.
  class Order < Model
    field :order_code
    field :status, OrderStatus
    field :amount, :float
    field :amount_currency
    field :products, [OrderProduct]
  end

  # Reads an order. CLI: dna order get
  class OrderGetRequest < BaseRequest
    endpoint :get, '/api/v1/order/{order_code}', safety: :read
    returns Order
    attribute :order_code

    def validate
      required :order_code
    end
  end

  # Reads orders. CLI: dna order
  class OrderService < Service
    # An order and its lines.
    def get(order_code)
      call(OrderGetRequest.new(order_code: order_code))
    end
  end
end
