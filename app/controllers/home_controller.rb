class HomeController < ApplicationController
  def index
  	if current_user
	  	redirect_to games_path
	  	return
	  end
  end
end
