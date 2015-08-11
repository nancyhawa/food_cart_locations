require 'nokogiri'
require 'open-uri'
require 'geocoder'
require 'rest_client'
require_relative 'parks_list'
require_relative 'key'
require 'pstore'
require 'pry'
require 'paint'
class FoodCarts

  def initialize
    @data = 'http://www.nycgovparks.org/bigapps/DPR_Eateries_001.xml'
    @food_carts_api = Nokogiri::XML(open(@data).read)
    @store = PStore.new("review_data.pstore")
    # Geocoder.configure(:lookup => :bing, :api_key => bing_key)
    # @user_location = get_user_location
  end

  def run
    puts "Welcome to Food Cart Finder!!!"
    main_menu
  end

  def main_menu
    puts "Would you like to FIND a cart or write a REVIEW?"
    get_user_input
    respond_to_mm_user_input
  end

  def respond_to_mm_user_input
    case @input.downcase
    when 'find'
      find_cart
    when 'review'
      puts "Ok.  First we'll need to find the cart that you are going to review."
      find_cart
    else
      puts "I didn't understand that."
      main_menu
    end
  end

  def exit_program
    if ["quit", "exit", "quit!", "leave", "q"].include?(@input)
    abort('Goodbye!')
    end
  end

  def find_cart
    puts "Would you like to tell us the name of your park, or have us determine the name of the closest park based on your location?  Enter '1' to give us a park, enter '2' to have us find a park near you."
    get_user_input
    case @input
    when '1'
      user_chooses_park
      print_food_cart_info
    when '2'
      @park = closest_park(get_user_location)
      print_food_cart_info
    else
      puts "I didn't understand that."
      find_cart
    end
    request_review
  end

  def user_chooses_park
    puts "Which park would you like to search?"
    @answer = gets.chomp
    respond_to_park_choice
  end

  def request_review
    puts "Would you like to add a review? Answer 'y' or 'n'."
    get_user_input
    write_review
  end

  def write_review
    if @input.downcase == 'y'
      user_chooses_cart
      user_rates_cart
      user_adds_comments
    elsif @input == 'n'
      main_menu
    else
      puts "I didn't understand that answer."
      request_review
    end
    store_review(@location, @rating, @comments)
    puts "Thank you for your review!"
    main_menu
  end

  def user_chooses_cart
    puts "Which cart would you like to review?  Select the cart by number."
    get_user_input
    @location = near_by_food_carts(@park)[@input.to_i - 1]
    puts "You selected #{@location} in #{@park}."
  end

  def user_rates_cart
    puts "Rate the cart from 1-5."
    @rating = gets.chomp
    if !["1", "2", "3", "4", "5"].include?(@rating)
      puts "I didn't understand that.  Please make sure your response is an integer between 1 and 5."
      user_rates_cart
    end
  end

  def user_adds_comments
    puts "Would you like to add comments?  Answer 'y' or 'n'."
    @response = gets.chomp.downcase
    if @response == 'y'
      puts "Ok, input your comments."
      @comments = gets.chomp
    if @response == 'n'
      puts "Ok, great.  I'll store your rating."
    else
      puts "I didn't understand that."
      user_adds_comments
    end
  end

  def get_user_input
    @input = gets.chomp
    exit_program
  end

  def print_food_cart_info
    puts "We are searching Central Park for food carts. #{@park}."
    puts "Here are the locations of the food carts in #{@park}:"
    near_by_food_carts(@park).each.with_index(1) do  |cart, i|
      puts "#{i}. #{cart}  RATING: #{get_rating(cart)}, COMMENTS:  #{get_comments(cart)}"
    end
  end

  def respond_to_park_choice
    # normalized_hash = park_list_hash.each_key { |key| key.downcase}
    if park_list_hash.has_key?(@answer)
      @park = @answer.split(" ").map { |x| x.capitalize }.join(" ")
      puts "The closest park to you is #{@park}."
      puts "Here are the locations of the food carts in #{@park}:"
      puts near_by_food_carts(@park)
    else
      puts "I'm sorry.  That park is not in our database."
      user_chooses_park
    end
  end


#--------------Methods for Creating Hard Coded Data Structures ----------------
def park_names
  parks = []
  @food_carts_api.css('facility').each do |facility|
    parks << facility.css('name').text.split(" Food Cart")[0]
  end
  parks.uniq
end

  def park_locations_hash
    hash = {}
    parks_with_locations.each do |park|
      hash[park] = park_coordinates(park)
      sleep 1
    end
    hash
  end
#--------------Methods for Determining Location ---------------------

  def park_coordinates(park)
    result = Geocoder.search(park)[0]
    if result
      latitude = result.latitude
    else
      latitude = 1000000000000000000
      #This is a work-around for park names not recognized by Geocoder.
    end

    if result
      longitude = result.longitude
    else
      longitude = 1000000000000000000
    end
    [latitude, longitude]
   end

  def closest_park(user_coordinates)
    min_distance = nil
    closest_park = nil

    park_list_hash.each do | park, coordinates |
      lat_diff = (coordinates[0] - user_coordinates[0]).abs
      long_diff = (coordinates[1] - user_coordinates[1]).abs
      distance = (lat_diff**2 + long_diff**2)**(0.5)
      if !min_distance || min_distance > distance
        min_distance = distance
        closest_park = park
      end
    end
    closest_park
  end

  def near_by_food_carts(park)
    nearby_carts = []
    @food_carts_api.css('facility').each do |cart|
      nearby_carts << cart.css('location').text if cart.css('name').text.include?(park)
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
#<---------------REVIEW_METHODS ----------------------->
  def initialize(park, location)
    @location = location
    @park = park
  end

  def store_review(location,rating,comment="NO COMMENTS")
    @store.transaction do
      @store[location] = {rating: rating, comment: comment}
    end
  end

  def get_rating(location)
     @store.transaction {@store[location][:rating]}
     rescue
     return "Unrated"
   end

  def get_comments(location)
    @store.transaction {@store[location][:comment]}
    rescue
    return "No comments"
  end

end

# print ["Happy", "sad", "angry"]
# print FoodCarts.new.parks_with_locations.length
# FoodCarts.new.park_names.size

 # print FoodCarts.new.park_locations_hash.select {|k,v| v != [1000000000000000000, 1000000000000000000] && !hash2.has_key?(k)}

 FoodCarts.new.run
