class GamesController < ApplicationController
  before_filter :require_login

  def index
  	@games = Game.where(status_cd: Game.waiting)
  	@new_game = Game.new 
 		@new_game.status = :waiting
  end

  def show
    my_player_number = nil

  	@game = Game.find(params[:id])
  	if (@game.player1.id != nil and @game.player1_id != current_user.id and
  		@game.player2_id != nil and @game.player2_id != current_user.id and
  		@game.player3_id != nil and @game.player3_id != current_user.id and
  		@game.player4_id != nil and @game.player4_id != current_user.id) or
      @game.status != :waiting
  		head :not_found and return
		end

    @bootstrap_data[:game] = @game 
    @bootstrap_data[:websocketUri] = "#{request.host}:#{request.port}/websocket"
  end

  def create
  	game = Game.create(params[:game]) do |g|
  		g.status = :waiting
  		g.player1 = current_user
  	end

  	redirect_to game
  end
end
