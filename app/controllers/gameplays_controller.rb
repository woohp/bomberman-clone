class GameplaysController < WebsocketRails::BaseController
	def start
    id = message[:id]
    game_map = message[:map]

    game = Game.where(id: id, status_cd: Game.waiting).first
    if game.nil?
      trigger_failure 'game does not exist' and return
    elsif game.player1_id != current_user.id
      trigger_failure 'not host of game' and return
    elsif game.player2_id.nil?
      trigger_failure 'no one has joined the game yet' and return
    end

    game.status = :in_progress
    game.save

	  WebsocketRails["game_#{game.id}"].trigger('start', game_map)
    trigger_success
	end

  def join
  	game = Game.where(id: message).first

  	trigger_failure if game.nil?
  	Game.transaction do
  		if game.player2_id.nil? or game.player2_id == current_user.id
  			game.player2 = current_user
  		elsif game.player3_id.nil? or game.player3_id == current_user.id
  			game.player3 = current_user
  		elsif game.player4_id.nil? or game.player4_id == current_user.id
  			game.player4 = current_user
  		else
  			trigger_failure game and return if game.nil?
  		end
  	end

    game.save

  	trigger_success game
  end
end