require 'nokogiri'
require 'open-uri'
require 'geocoder'
require 'rest_client'
require 'pstore'
require 'pry'
require 'table_print'

class Reviews
  attr_accessor :park, :location, :rating, :comment

  def initialize(park, location, rating, comment=nil)
    @park = park
    @location = location
    @rating = rating
    @comment = comment
  end

  def delete_reviews
    File.delete("./lib/review_data.pstore")
    rescue
    return "Data file does not exist"
  end
end

class CLI

  def initialize
    @data = 'http://www.nycgovparks.org/bigapps/DPR_Eateries_001.xml'
    @food_carts_api = Nokogiri::XML(open(@data).read)
    @store = PStore.new("./lib/review_data.pstore")
    # Geocoder.configure(:lookup => :bing, :api_key => bing_key)
    # @user_location = get_user_location
  end

  def run
    puts "Welcome to Food Cart Finder!!!"
    main_menu
  end

  def main_menu
    puts "Would you like to FIND a cart, WRITE a review, VIEW your old reviews?"
    get_user_input
    respond_to_mm_user_input
  end

  def respond_to_mm_user_input
    case @input.downcase
    when 'find'
      find_cart
    when 'write'
      puts "Ok.  First we'll need to find the cart that you are going to review."
      find_cart
    when 'view'
      print_full_table
      delete_reviews_option
      main_menu
    else
      puts "I didn't understand that."
      main_menu
    end
  end

  def delete_reviews_option
    puts "If you would like to clear all of your reviews, type 'clear'.  This data will be lost FOREVER."
    get_user_input
    if @user_input == 'clear'
      delete_reviews
      puts "Your previous reviews have been deleted."
    end
  end

  def print_full_table
    # if @store
      food_carts_table = []
      locations = @store.transaction { @store.roots }
      locations.each do |cart|
        food_carts_table << @store.transaction { @store[cart] }
      end
      puts "==========REVIEWS FOR ALL PARKS==========="
      tp food_carts_table, :park, {:location => {:width => 50}}, :rating, :comment
  end

  def print_park_table
    food_carts_table = []
    locations = @store.transaction { @store.roots }
    locations.each do |cart|
      if cart.split(":")[0] == @park
        food_carts_table << @store.transaction { @store[cart] }
      end
    end
      if  !food_carts_table.empty?
        puts "==========REVIEWS FOR #{@park}==========="
        (tp food_carts_table, :park, {:location => {:width => 50}}, :rating, :comment)
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
      puts "The closest park to you is #{@park}."
      puts "Would you like us to pull up a Google map of the area.  (Be forewarned - sometimes Google maps is wonky.)"
      get_user_input
      open_park(@park) if @input == 'y'
      print_food_cart_info
    else
      puts "I didn't understand that."
      find_cart
    end
    review_or_map
  end

  def user_chooses_park
    puts "Which park would you like to search?"
    @input = gets.chomp
    respond_to_park_choice
  end

  def request_review_new_location
    puts "Would you like to add a review? Answer 'y' or 'n'."
    get_user_input
    if @input.downcase == 'y'
      user_chooses_cart
      set_location
      write_review
      store_review
    elsif @input == 'n'
      main_menu
    else
      puts "I didn't understand that answer."
      request_review_new_location
    end
  end

  def request_review_same_location
    puts "Would you like to add a review? Answer 'y' or 'n'."
    get_user_input
    if @input.downcase == 'y'
      write_review
      store_review
    elsif @input == 'n'
      main_menu
    else
      puts "I didn't understand that answer."
      request_review_same_location
    end
  end

  def write_review
    puts "You are reviewing #{@location} in #{@park}."
    puts
    user_rates_cart
    user_adds_comments
  end

  def store_review
    @store.transaction { @store["#{@park}: #{@location}"] = Reviews.new(@park, @location, @rating, @comments) }

    puts "Thank you for your review!"
    main_menu
  end

  def review_or_map
    puts "Would you like to add a REVIEW or view a MAP?"
    get_user_input
    case @input
    when 'review'
      @input = 'y'
      user_chooses_cart
      set_location
      write_review
      store_review
    when 'map'
      user_chooses_cart
      set_location
      puts "You selected #{@location} in #{@park}."
      puts
      open_cart(@location)
      request_review_same_location
    else
      puts "I didn't understand that."
      review_or_map
    end
  end

  def user_chooses_cart
    puts "Which cart would you like to select?  Select the cart by number."
    get_user_input
  end

  def set_location
    @location = near_by_food_carts(@park)[@input.to_i - 1]
  end

  def ask_user_cart_map
      puts "Would you like us to pull up a Google map of the area.  (Be forewarned - sometimes Google maps is wonky.)"
      get_user_input
      open_cart(@location) if @input == 'y'
  end

  def user_rates_cart
    puts "Rate the cart from 1-5."
    @rating = gets.chomp
    puts
    if !["1", "2", "3", "4", "5"].include?(@rating)
      puts "I didn't understand that.  Please make sure your response is an integer between 1 and 5."
      user_rates_cart
    end
  end

  def user_adds_comments
    puts "Would you like to add comments?  Answer 'y' or 'n'."
    get_user_input
    if @input == 'y'
      puts "Ok, input your comments."
      @comments = gets.chomp
    elsif @input == 'n'
      puts "Ok, great.  I'll store your rating."
    else
      puts "I didn't understand that."
      user_adds_comments
    end
  end

  def get_user_input
    @input = gets.chomp
    puts
    exit_program
  end

  def print_food_cart_info
    puts "We are searching #{@park} for food carts. #{@park}."
    puts "Here are the locations of the food carts in #{@park}:"
    near_by_food_carts(@park).each.with_index(1) do  |cart, i|
      puts "#{i}. #{cart}"
    end
    print_park_table
  end

  def respond_to_park_choice
    # normalized_hash = park_list_hash.each_key { |key| key.downcase}
    if park_list_hash.has_key?(@input.split(" ").map! { |x| x.capitalize }.join(" "))
      @park = @input.split(" ").map { |x| x.capitalize }.join(" ")
      puts "Would you like us to pull up a Google map of #{@park}?"
      response = gets.chomp.downcase
      open_park(@park) if response == 'y'
      # puts "The closest park to you is #{@park}."
      # puts "Here are the locations of the food carts in #{@park}:"

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


  def park_coordinates(park)
    ##This method was created to programatically create a hash that we then hard coded into our program.
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
#--------------Methods for Determining Location ---------------------
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
   return latitude, longitude
  end
#<---------------REVIEW_METHODS ----------------------->
  #The methods below were used only for an old iteration of this program.
  # def store_review(location,rating,comment="NO COMMENTS")
  #   @store.transaction { @store[location] = {rating: rating, comment: comment} }
  # end

  # def get_rating(location)
  #    @store.transaction {@store[location][:rating]}
  #    rescue
  #    return "Unrated"
  #  end
  #
  # def get_comments(location)
  #   @store.transaction {@store[location][:comment]}
  #   rescue
  #   return "No comments"
  # end

  def delete_reviews
   File.delete("review_data.pstore")
   rescue
   return "Data file does not exist"
  end

 def open_park(park)
   lat = park_list_hash[park][0]
   long = park_list_hash[park][1]
   system("open", "https://www.google.com/maps/search/#{lat},#{long}")
 end

 #This will open the cart location
 def open_cart(location)
   system("open", "https://www.google.com/maps/search/#{@location}")
 end


end

#<---------------GOOGLE_MAPS ----------------------->
#This will open the park based on latitude/longitude

# print ["Happy", "sad", "angry"]
# print FoodCarts.new.parks_with_locations.length
# FoodCarts.new.park_names.size

 # print FoodCarts.new.park_locations_hash.select {|k,v| v != [1000000000000000000, 1000000000000000000] && !hash2.has_key?(k)}

CLI.new.run
 #FoodCarts.new.run
