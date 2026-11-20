# frozen_string_literal: true

module DomainNameApi
  # The reseller account and its balances.
  class Account < Model
    field :reseller_id
    field :reseller_name
    field :reseller_group_name
    field :try_balance, :float, from: 'tryBalance'
    field :usd_balance, :float, from: 'usdBalance'

    # The balance in a currency, "USD" or "TRY" (any case); nil for other
    # currencies: the account holds only these two.
    def balance(currency = 'USD')
      case currency.to_s.strip.upcase
      when 'USD' then usd_balance.to_f
      when 'TRY', 'TL' then try_balance.to_f
      end
    end
  end

  # One entry of the balance ledger.
  class Transaction < Model
    field :trace_id
    field :type, TransactionType
    field :status, TransactionStatus
    field :charge_type, ChargeType
    field :amount, :float
    field :amount_currency
    field :exchange_amount, :float
    # Numeric in the API.
    field :exchange_currency, :float
    field :product_type, ProductType
    field :product_id
    field :description
    # Number of years bought, for domain transactions.
    field :period, :integer
    field :creation_time, :time
    field :reseller_name
    # Balance after the transaction.
    field :balance, :float
    # Balance before it.
    field :old_balance, :float

    # How the transaction moved the balance: positive for credits, negative for
    # charges. Reliable even when amount is 0.
    def change
      ((balance.to_f - old_balance.to_f) * 100).round / 100.0
    end
  end

  # Reads the account. CLI: dna account get
  class AccountGetRequest < BaseRequest
    endpoint :get, '/api/v1/deposit/accounts/me', safety: :read
    returns Account
  end

  # Lists balance transactions. CLI: dna account transactions
  class AccountTransactionsRequest < PagedRequest
    endpoint :get, '/api/v1/deposit/transactions', safety: :read
    returns Page.of(Transaction)

    # Keeps only these kinds (TransactionType: :register, :renew, ...).
    attribute :transaction_types, default: []
    # Keeps only these product kinds (ProductType).
    attribute :product_types, default: []
    # Keeps only credits (:add) or debits (:subtract).
    attribute :charge_type
    # Keeps only these currencies, e.g. ["USD"].
    attribute :currencies, default: []
    # Limit the creation time (Time, Date or ISO 8601 string).
    attribute :from
    attribute :to
    # Finds one transaction.
    attribute :trace_id
    # Search the text.
    attribute :description
    attribute :filter_text
    # Keeps only transactions of this amount.
    attribute :amount

    def query
      q = params
          .repeated('TransactionTypes', Array(transaction_types).map { |t| TransactionType[t] || t })
          .repeated('ProductTypes', Array(product_types).map { |t| ProductType[t] || t })
          .repeated('AccountCurrencyTypes', currencies)
          .time('StartDate', from)
          .time('EndDate', to)
          .string('TraceId', trace_id)
          .string('Description', description)
          .string('FilterText', filter_text)
          .number('Amount', amount)
          .page(skip: skip, limit: limit, sort: sort)
      q.always('ChargeType', ChargeType.parse(charge_type).value) if ChargeType[charge_type]
      q
    end

    def validate
      super
      Array(transaction_types).each { |t| enum(:transaction_types, TransactionType, t) }
      Array(product_types).each { |t| enum(:product_types, ProductType, t) }
      enum(:charge_type, ChargeType)
      check(from.nil? || Util.parse_time(from), :from, 'is not a date')
      check(to.nil? || Util.parse_time(to), :to, 'is not a date')
      f = Util.parse_time(from)
      t = Util.parse_time(to)
      check(f.nil? || t.nil? || t >= f, :to, 'must not be before from')
    end
  end

  # The reseller account: balances and the balance ledger. CLI: dna account
  class AccountService < Service
    # The account and its TRY and USD balances. Also the cheapest way to check
    # that the credentials work.
    def get
      call(AccountGetRequest.new)
    end

    # One page of the balance ledger.
    #
    #   client.account.transactions(from: Date.new(2026, 1, 1), transaction_types: [:renew], limit: 50)
    def transactions(request = nil, **filters)
      call(build(AccountTransactionsRequest, request, filters))
    end

    # Every matching transaction, fetching pages as you go. Returns an
    # Enumerator, or iterates when given a block.
    #
    #   client.account.all_transactions(from: month_start) { |tx| puts "#{tx.creation_time} #{tx.type} #{tx.change}" }
    def all_transactions(request = nil, **filters, &block)
      enum = paginate(build(AccountTransactionsRequest, request, filters)) { |req| call(req) }
      block ? enum.each(&block) : enum
    end
  end
end
