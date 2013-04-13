class GameplaysController < WebsocketRails::BaseController
	def start
    id = message[:id]
    game_map = message[:map]

    game = Game.where(id: id).first
    if game.nil?
      trigger_failure 'game does not exist' and return
    elsif game.player1_id != current_user.id
      trigger_failure 'not host of game' and return
    elsif game.player2_id.nil?
      trigger_failure 'no one has joined the game yet' and return
    elsif game.status == :done
      trigger_failure 'game has ended already'
    end

    game.status = :in_progress
    game.save

	  WebsocketRails["game_#{game.id}"].trigger('start', game_map)
    trigger_success
	end

  def join
  	game = Game.where(id: message).first

    # fail if game not found
  	trigger_failure if game.nil?

    # if the player has already joined, do nothing
    if game.player2_id == current_user.id or
      game.player3_id == current_user.id or
      game.player4_id == current_user.id
      trigger_success game and return
    end

  	Game.transaction do
  		if game.player2_id.nil?
  			game.player2 = current_user
  		elsif game.player3_id.nil?
  			game.player3 = current_user
  		elsif game.player4_id.nil?
  			game.player4 = current_user
  		else
  			trigger_failure game and return if game.nil?
  		end
  	end
    game.save

    WebsocketRails["game_#{game.id}"].trigger('playerJoined', current_user.username)
  	trigger_success game
  end

  def won
    current_user.wins ||= 0
    current_user.wins += 1
    current_user.save

    trigger_success
  end

  def lost
    current_user.loses ||= 0
    current_user.loses += 1
    current_user.save

    trigger_success
  end
end