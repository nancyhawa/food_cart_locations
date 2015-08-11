require 'nokogiri'
require 'open-uri'
require 'geocoder'
require 'rest_client'
require_relative 'parks_list'
class FoodCarts

  def initialize
    @data = 'http://www.nycgovparks.org/bigapps/DPR_Eateries_001.xml'
    @food_carts_api = Nokogiri::XML(open(@data).read)
  end

  def run
    @park = closest_park(get_user_location)
    puts "The closest park to you is #{park}."
    puts "Here are the locations of the food carts in #{park}"
  end

  def park_names
    parks = []
    @food_carts_api.css('facility').each do |facility|
      parks << facility.css('name').text.split(" Food Cart")[0]
    end
    parks.uniq
  end


  # def parks_without_locations
  #   park_names.select { |park| !Geocoder.search(park)[0] }  # ~> NameError: undefined local variable or method `parks_names' for #<FoodCarts:0x007ff8342320d8>
  # end

  def park_coordinates(park)
    result = Geocoder.search(park)[0]
    latitude = result.latitude
    longitude = result.longitude
    if !latitude || !longitude
      return "There is no location data for this #{park}"
    end
    [latitude, longitude]
   end

  def closest_park(user_coordinates)
    min_distance = nil
    closest_park = nil

    parks_with_locations.each do | park |
      lat_diff = (park_coordinates(park)[0] - user_coordinates[0]).abs
      long_diff = (park_coordinates(park)[1] - user_coordinates[1]).abs
      distance = (lat_diff**2 + long_diff**2)**(0.5)
      if !min_distance || min_distance > distance
        min_distance = distance
        closest_park = park
      end
    end
    closest_park
  end

  def food_carts_in_closest_park(park)
    nearby_carts = []
    @food_carts_api.css('facility').each do |cart|
      nearby_carts << cart.css('location') if cart.css('name').include?(park)
    end
    nearby_carts
  end

  def get_user_location
   ip = RestClient.get("http://echoip.net/")
   results = Geocoder.search(ip)[0]
   latitude = results.latitude
   longitude = results.longitude
  #  system("open", "https://www.google.com/maps/search/#{latitude},#{longitude}")
   return latitude, longitude
  end

end
# print ["Happy", "sad", "angry"]
# print FoodCarts.new.parks_with_locations.length
# FoodCarts.new.park_names.size

FoodCarts.new.run
