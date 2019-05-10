class FlightsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :create_flights, only: :index
  before_action :format_flight_name, only: [:show, :purchase]
  before_action :format_amount, only: :purchase

  def index
  end

  def show
  end

  def purchase
  end

  def transaction
    amount = amount_to_charge(params[:name].split('-').last.to_i)
    third_party_purchase = params[:third_party] || false

    if third_party_purchase
      third_party_distribution(amount)
    else
      gateway_transaction(amount)
    end
  end

  def list_transactions
    url = "https://core.spreedly.com/v1/transactions.json?order=desc&count=100"

    @transactions = HttpClient.fetch_paginated_data(url)
  end

  private def gateway_transaction(amount)
    @env = Spreedly::Environment.new(ENV["SPREEDLY_ENV"], ENV["ACCESS_SECRET"])

    retain = params[:retain] || false

    transaction = @env.purchase_on_gateway(ENV["TEST_GATEWAY_TOKEN"], params[:payment_method_token], amount, retain_on_success: retain)

    if transaction.succeeded?
      flash[:notice] = "#{transaction.message} Payment received!"
    else
      flash[:alert] = "There was a problem with your transaction: #{transaction.message}"
    end

    redirect_to flight_url(name: params[:name].parameterize)
  end

  private def third_party_distribution(amount)
    url = "https://core.spreedly.com/v1/receivers/#{ENV["PMD_GATEWAY_TOKEN"]}/deliver.json"

    body = "{
        \"delivery\": {
          \"payment_method_token\": \"#{params[:payment_method_token]}\",
          \"url\": \"https://spreedly-echo.herokuapp.com\",
          \"headers\": \"Content-Type: application/json\",
          \"body\": \"{ \\\"flight\\\": \\\"#{params[:name]}\\\", \\\"amount\\\": \\\"#{amount}\\\", \\\"card_number\\\": \\\"{{credit_card_number}}\\\" }\"
        }
      }"

    response = HttpClient.make_request(:post, url, body)
    parsed_response = JSON.parse response.body

    if parsed_response['transaction']['response']['status'] == 200
      flash[:notice] = "Payment successfully delivered to third party seller!"
    else
      flash[:alert] = "There was a problem with your transaction."
    end
    
    redirect_to flight_url(name: params[:name].parameterize)
  end

  private def amount_to_charge(base)
    base * 10 + (base.divmod(10).last * 205)
  end

  private def cost_to_dollars(amount)
    amount.to_f / 100
  end

  private def format_flight_name
    @flight_name = params[:name].split("-").join(" ").humanize
  end

  private def format_amount
    @amount = cost_to_dollars(amount_to_charge(params[:name].split('-').last.to_i))
  end

  private def create_flights
    @flights = 10.times.map{ |n| Flight.new(name: "Flight 100#{n}", cost: amount_to_charge("100#{n}".to_i)) }
  end
end
