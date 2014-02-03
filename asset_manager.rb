# rubocop:disable LineLength
#
#
### Recursos

### Listar todos los recursos       DONE
### Ver un recurso                  DONE
### Listar reservas de un recurso   DONE
### Disponibilidad de un recurso    DONE
### Reservar recurso                DONE
### Cancelar reserva                DONE
### Autorizar reserva               DONE
### Mostrar una reserva             DONE
#
#

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/json'
require 'pry'

set :database, 'sqlite3:///./asset_manager.sqlite3'
set :port, 9292
set :hostname, 'localhost'

class Resource < ActiveRecord::Base
  has_many :bookings
  def available_slots?(start, finish)
    start = start.to_datetime.strftime('%Y-%m-%d %H:%M:00.000000')
    finish = finish.to_datetime.strftime('%Y-%m-%d %H:%M:00.000000')
    bookings = Booking.where('resource_id = ? AND start >= ? AND start <= ? AND status = ?', id, start, finish, 'approved')
    avail = bookings.all.collect { |b| [b.start, b.finish] }.sort.flatten
    avail.insert(0, start)
    avail.insert(-1, finish)
    avail.each_slice(2).to_a
#    return avail
  end

#  def slot_available?(start, finish)
    # date = start.to_date.strftime('%Y-%m-%dT00:00:00Z')
    # to = (start.to_date + 1).strftime('%Y-%m-%dT00:00:00Z')
    # res = available_slots?(start, finish).select { |slot| slot[0] <= start && slot[1] >= finish }.size
#    available_slots?(start, finish).size == 1
    # res == 1
#  end
end

class Booking < ActiveRecord::Base
  belongs_to :resource
  # validates :start, presence: true
  # validates :finish, presence: true
  # validates :user, presence: true

  def pending?
    status == 'pending'
  end
end

helpers do
  def resource_link(res_id, rel)
    { 'rel' => rel, 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}" }
  end

  def booking_link(res_id, book_id, rel)
    { 'rel' => rel, 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}/bookings/#{book_id}" }
  end

  def new_booking_link(res_id, rel)
    { 'rel' => rel, 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}/bookings", 'method' => 'POST' }
  end

  def bookings_all_link(res_id, rel)
    { 'rel' => rel, 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}/bookings/all" }
  end

  def accept_link(res_id, book_id)
    { 'rel' => 'accept', 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}/bookings/#{book_id}", 'method' => 'PUT' }
  end

  def reject_link(res_id, book_id)
    { 'rel' => 'reject', 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{res_id}/bookings/#{book_id}", 'method' => 'DELETE' }
  end
end

get '/resources' do
  resources = Resource.all
  resources.collect! { |r|  { name: r.name, description: r.description, links: [resource_link(r.id, 'self')] } }
  body = { resources: resources, links: [{ rel: 'self', uri: "http://#{settings.hostname}:#{settings.port}/resources" }] }
  json body
end


get '/resources/:id' do
  resource = Resource.find_by_id(params[:id])
  if resource.nil?
    status 404
  else
    links = [resource_link(resource.id, 'self'), bookings_all_link(resource.id, 'bookings')]
    body = { 'resource' => { 'name' => resource.name, 'description' => resource.description, 'links' => links } }
    json body
  end
end

get '/bookings' do
  bookings = Booking.all
  body = { 'bookings' => bookings }
  json body
end

get '/resources/:id/bookings/all' do
  bookings = Booking.where('resource_id = ?', params[:id]).all
  bookings.collect! do |b|
    links = [booking_link(b.resource_id, b.id, 'self'), resource_link(b.resource_id, 'resource'), accept_link(b.resource_id, b.id), reject_link(b.resource_id, b.id)]
    { 'start' => b.start, 'finish' => b.finish, 'status' => b.status, 'user' => b.user, 'links' => links }
  end
  body = { 'bookings' => bookings }
  json body
end

get '/resources/:id/bookings' do

  # resumir a 3 lineas
  params[:limit] ||= 30
  params[:date] ||= Time.now + 1
  params[:status] ||= 'approved'
  limit = params[:limit].to_i
  limit > 365 ? limit = 365 : limit
  date = params[:date].to_date.strftime('%Y-%m-%d 00:00:00.000000')
  to = (params[:date].to_date + limit).strftime('%Y-%m-%d 00:00:00.000000')
 # status= params[:status] == 'all'? '*' : params[:status]
  # usar "*" para matchear todos los status y resumir a una linea
  

  if params[:status] != 'all'
    bookings = Booking.where('resource_id = ? AND start >= ? AND start <= ? AND status = ?', params[:id], date, to, params[:status]).all
  else
    bookings = Booking.where('resource_id = ? AND start >= ? AND start <= ?', params[:id], date, to).all
  end


  bookings.collect! do |b|
    links = [booking_link(b.resource_id, b.id, 'self'), resource_link(b.resource_id, 'resource'), accept_link(b.resource_id, b.id), reject_link(b.resource_id, b.id)]
    { 'start' => b.start, 'finish' => b.finish, 'status' => b.status, 'user' => b.user, 'links' => links }
  end
  body = { 'bookings' => bookings, :links => [{ 'rel' => 'self', 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{params[:id]}/bookings?date=#{params[:date]}&limit=#{params[:limit]}&status=#{params[:status]}" }] }
  json body
end

get '/resources/:id/availability' do
  params[:limit] ||= '30'
  params[:date] ||= Time.now + 1
  limit = params[:limit].to_i
  limit > 365 ? limit = 365 : limit = limit
  date = params[:date].to_date.strftime('%Y-%m-%dT00:00:00Z')
  to = (params[:date].to_date + limit).strftime('%Y-%m-%dT00:00:00Z')

  resource = Resource.find(params[:id])
  avail = resource.available_slots?(date, to)
  avail.collect! do |a|
    links = [new_booking_link(params[:id], 'book'), resource_link(params[:id], 'resource')]
    { 'from' => a[0], 'to' => a[1], 'links' => links }
  end
  body = { 'availability' => avail, :links => [{ 'rel' => 'self', 'uri' => "http://#{settings.hostname}:#{settings.port}/resources/#{params[:id]}/availability?date=#{params[:date].to_date.strftime('%Y-%m-%d')}&limit=#{params[:limit]}" }] }
  json body
end

post '/resources/:id/bookings' do
  if params[:from].nil? || params[:to].nil? || params[:user].nil?
    status 400
  else
    resource = Resource.find_by_id(params[:id])
    if resource.nil?
      status 404
    else
      new_booking = Booking.new
      new_booking.resource_id = params[:id]
      new_booking.start = params[:from].to_datetime.strftime('%Y-%m-%d %H:%M:00.000000')
      new_booking.finish = params[:to].to_datetime.strftime('%Y-%m-%d %H:%M:00.000000')
      new_booking.user = params[:user]
      new_booking.status = 'pending'
      if new_booking.save
        status 201
        links = [booking_link(new_booking.resource_id, new_booking.id, 'self'), accept_link(new_booking.resource_id, new_booking.id), reject_link(new_booking.resource_id, new_booking.id)]
        book = { 'from' => new_booking.start, 'to' => new_booking.finish, 'status' => new_booking.status, 'links' =>  links }
        body = { 'book' => book }
        json body
      end
    end
  end
    # sucess = 201 CREATED
    # not available = 409 CONFLICT
    # missing arguments = 400 BAD REQUEST
end

delete '/resources/:r_id/bookings/:b_id' do
  booking = Booking.where('id= ? AND resource_id = ?', params[:b_id], params[:r_id]).first
  if booking.nil?
    status 404
  else
    booking.destroy
  end
    # sucess = 200 OK
    # not found = 404 NOT FOUND
end

put '/resources/:r_id/bookings/:b_id' do
  booking = Booking.where('id= ? AND resource_id = ?', params[:b_id], params[:r_id]).first
  resource = Resource.find_by_id(params[:r_id])
  if booking.nil?
    status 404
  elsif resource.available_slots?(booking.start, booking.finish).size == 1 
    booking.status = 'approved'
    if booking.save
      links = [booking_link(booking.resource_id, booking.id, 'self'),  accept_link(booking.resource_id, booking.id), reject_link(booking.resource_id, booking.id), resource_link(booking.resource_id, 'resource')]
      book = { 'from' => booking.start, 'to' => booking.finish, 'status' => booking.status, 'links' => links }
      body = { 'book' => book }
      json body
    end
    else
      status 409
  end
    # success 200 OK
    # no found 404 NOT FOUND    status 404
    # already anoher approved 409 CONFLICT
end

get '/resources/:r_id/bookings/:b_id' do
  booking = Booking.where('id= ? AND resource_id = ?', params[:b_id], params[:r_id]).first
  if booking.nil?
    status 404
  else
    links = [booking_link(booking.resource_id, booking.id, 'self'), accept_link(booking.resource_id, booking.id), reject_link(booking.resource_id, booking.id), resource_link(booking.resource_id, 'resource')]
    book = { 'from' => booking.start, 'to' => booking.finish, 'status' => booking.status, 'links' => links }
    body = { 'book' => book }
    json body
  end
end
