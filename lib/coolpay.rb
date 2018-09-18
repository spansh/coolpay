require "coolpay/version"
require "faraday"
require "json"
require "coolpay/exceptions"

class Coolpay
  attr_reader :base_url, :username, :api_key, :token, :useragent
  def initialize(
    base_url: "https://coolpay.herokuapp.com",
    username: nil,
    api_key: nil
  )
    @base_url = base_url
    @username = username
    @api_key = api_key
    @useragent = Faraday.new(@base_url)
  end

  def authenticate
    response = send_post("/api/login", { username: @username, apikey: @api_key })
    unless response.success?
      raise Coolpay::ApiError.new("Could not login to coolpay #{response.reason_phrase} #{response.body}")
    end

    @token = JSON.parse(response.body)["token"]
  end

  def search_recipients( query = nil )
    params = {}
    unless query.nil?
      params["name"] = query
    end
    response = send_authenticated_get("/api/recipients", params)

    unless response.success?
      raise Coolpay::ApiError.new("Could not fetch recipient list #{response.reason_phrase} #{response.body}")
    end
    return JSON.parse(response.body)["recipients"]
  end

  def create_recipient( name )
    # NB documentation for create_recipient is wrong, it doesn't take a name query parameter
    response = send_authenticated_post("/api/recipients", { "recipient": { "name": name } } )

    unless response.success?
      raise Coolpay::ApiError.new("Could not create recipient #{response.reason_phrase} #{response.body}")
    end

    return JSON.parse(response.body)["recipient"]["id"]
  end

  def list_payments
    response = send_authenticated_get("/api/payments")

    unless response.success?
      raise Coolpay::ApiError.new("Could not fetch recipient list #{response.reason_phrase} #{response.body}")
    end
    return JSON.parse(response.body)["payments"]
  end

  def create_payment( from: nil, recipient: nil, currency_code: "GBP", amount: 0)
    # NB documentation for create_payment is wrong, request body is actually the
    # response, guessing at the API call based on create_user

    if from.nil? || recipient.nil?
      raise ArgumentError.new("from and to are mandatory to send payments")
    end

    response = send_authenticated_post("/api/payments", 
      {
        "payment": { 
          "id": from,
          "recipient_id": recipient,
          "currency": currency_code,
          "amount": amount
        }
      }
    )

    unless response.success?
      raise Coolpay::ApiError.new("Could not create recipient #{response.reason_phrase} #{response.body}")
    end

    return JSON.parse(response.body)["payment"]["status"]

  end

private

  def auth_header
    return "Bearer #{@token}"
  end

  def token_set?
    if (!defined? @token) || @token.nil?
      return false
    end
    return true
  end

  def send_authenticated_get(url, params = {})
    unless token_set?
      authenticate
    end

    response = @useragent.get do |request|
      request.url url
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = auth_header
      if (params)
        request.params = params
      end
    end

    return response
  end

  def send_authenticated_post(url, data)
    unless token_set?
      authenticate
    end
    response = @useragent.post do |request|
      request.url url
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = auth_header
      request.body = data.to_json
    end

    return response
  end

  def send_post(url, data)
    response = @useragent.post do |request|
      request.url url
      request.headers["Content-Type"] = "application/json"
      request.body = data.to_json
    end

    return response
  end
end
