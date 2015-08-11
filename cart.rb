class Cart

  def initialize

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
