require 'minitest/autorun'
require 'rack/test'
require 'pry'

require_relative 'asset_manager.rb'

class AssetMgrTest < Minitest::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_get_resources
    get '/resources'
    assert_equal 200, last_response.status
    last_response.headers['Content-Type'].must_equal 'application/json;charset=utf-8'
  end

  def test_get_resource_success
    get '/resources/1'
    assert_equal 200, last_response.status
    last_response.headers['Content-Type'].must_equal 'application/json;charset=utf-8'
  end

  def test_get_resource_fail
    get '/resources/100'
    assert_equal 404, last_response.status
  end

  def test_get_bookings_success
    get '/resources/1/bookings'
    assert_equal 200, last_response.status
    last_response.headers['Content-Type'].must_equal 'application/json;charset=utf-8'
  end

  def test_get_booking_success
    get '/resources/1/bookings/29'
    assert_equal 200, last_response.status
    last_response.headers['Content-Type'].must_equal 'application/json;charset=utf-8'
  end

  def test_get_booking_fail
    get '/resources/1/bookings/1'
    assert_equal 404, last_response.status
  end

  def test_delete_booking_fail
    delete '/resources/1/bookings/1'
    assert_equal 404, last_response.status
  end

  def test_approve_booking_fail_not_found
    put '/resources/1/bookings/1'
    assert_equal 404, last_response.status
  end

  def test_approve_booking_fail_conflict
    put '/resources/1/bookings/29'
    assert_equal 409, last_response.status
  end

  def test_create_booking_fail_not_found
    post '/resources/1000/bookings', 'from' => '2014-04-01 10:00', 'to' => '2014-04-01 11:00', 'user' => 'luiggi@gmail.com'
    assert_equal 404, last_response.status
  end

  def test_create_approve_delete_booking
    post '/resources/1/bookings', 'from' => '2014-04-01 10:00', 'to' => '2014-04-01 11:00', 'user' => 'luiggi@gmail.com'
    assert_equal 201, last_response.status
    new_id = MultiJson.load(last_response.body, symbolize_keys: true)[:book][:links][0][:uri].split('/').last.to_i
    put "/resources/1/bookings/#{new_id}"
    assert_equal 200, last_response.status
    delete "/resources/1/bookings/#{new_id}"
    assert_equal 200, last_response.status
  end

  def test_create_fail
    post '/resources/1/bookings'
    assert_equal 400, last_response.status
  end
end
