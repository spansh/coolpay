require "test/unit"
require "coolpay"
require "coolpay/exceptions"
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :faraday
end

class CoolpayTest < Test::Unit::TestCase
  attr_reader :username, :api_key

  def setup
    @username = "GarethH"
    @api_key = "945AF053C4694E1E"
  end

  def test_constructor
    vm = Coolpay.new
    assert_not_nil(vm,"Basic constructor was not successful")
  end

  def test_login
    VCR.use_cassette("login") do
      cp = Coolpay.new(username: @username, api_key: @api_key)
      cp.authenticate
      assert_not_nil cp.token, "Could not generate token from authenticate call"
      assert_raise Coolpay::ApiError, "Did not throw error when trying to login with invalid credentials" do
        cp = Coolpay.new(username: "NotValid", api_key: "still_not_valid")
        cp.authenticate
      end
    end
  end

  def test_search_recipients
    VCR.use_cassette("search_recipients") do
      cp = Coolpay.new(username: @username, api_key: @api_key)
      assert_operator cp.search_recipients.length,:>=,0,"Could not fetch unfiltered recipient list"
      assert_equal [],cp.search_recipients("this should never be found"),"Could not fetch filtered recipient list"
    end
  end

  def test_create_recipient
    VCR.use_cassette("create_recipient") do
      cp = Coolpay.new(username: @username, api_key: @api_key)
      assert_match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, cp.create_recipient("Harry Tester"),"Could not create recipient")
    end
  end

  def test_list_payments
    VCR.use_cassette("list_payments") do
      cp = Coolpay.new(username: @username, api_key: @api_key)
      assert_operator cp.list_payments.length,:>=,0,"Could not fetch payment list"
    end
  end

  def test_create_payment
    VCR.use_cassette("create_payment") do
      cp = Coolpay.new(username: @username, api_key: @api_key)
      from = cp.create_recipient("Harry Sender")
      recipient = cp.create_recipient("Harriet Recipient")
      assert_equal "processing",cp.create_payment( from: from, recipient: recipient, amount: 10.0 ),"Could not create payment"
      assert_raise ArgumentError, "Did not throw error when trying to pay without from user id" do
        cp.create_payment( recipient: recipient, amount: 10.0 )
      end
      assert_raise ArgumentError, "Did not throw error when trying to payment without recipient user id" do
        cp.create_payment( from: from, amount: 10.0 )
      end
    end
  end

end
