jQuery ->
  initNetwork() if bootstrap_data.current_user and bootstrap_data.websocketUri


# constants
EMPTY = 0
BRICK = 1
BOX = 2
GRID_SIZE = 48

LEFT = 0
UP = 1
RIGHT = 2
DOWN = 4


# class definitions
class Unit
  constructor: (@name, @y, @x) ->
    @pixelY = @y * GRID_SIZE
    @pixelX = @x * GRID_SIZE
    @dead = false

  centerPosition: ->
    [Math.round(@pixelY / GRID_SIZE), Math.round(@pixelX / GRID_SIZE)]
  
  update: ->

  # called when to determine what happens when one unit collides with another
  # this unit may do something to the other unit
  # returns a boolean on whether the other unit is physically colliding with this
  #   indicating whether these 2 units may overlap
  collide: (unit) -> false

  drawStatic: (ctx) ->

  drawAnimated: (ctx) ->
    @drawStatic(ctx)

class Player extends Unit
  constructor: (@playerName, y, x) ->
    super('player', y, x)
    @startingY = y
    @startingX = x
    @reallyDead = false # used to indicate whether to truly 

    @speed = 14
    @vision = 7

    # items related
    @numBombs = 1
    @numShurikens = 1
    @numRadars = 1
    @numShields = 1
    @bombStrength = 3
    @freezeStartTime = 0
    @shieldStartTime = 0

    # movement related variables
    @targetY = y
    @targetX = x
    @dy = 0
    @dx = 0
    @dPixelY = 0
    @dPixelX = 0
    @stepsLeft = 0
    @direction = DOWN

    $('#bomb-count').html(@numBombs)
    $('#shuriken-count').html(@numShurikens)
    $('#radar-count').html(@numRadars)
    $('#shield-count').html(@numShields)

  pixelBottom: -> @pixelY + GRID_SIZE
  pixelRight: -> @pixelX + GRID_SIZE

  _addItem: (variableName, displayID) ->
    return unless @playerName.match(myPlayerIndex+1)
    this[variableName] += 1
    $(displayID).html(this[variableName])
  _removeItem: (variableName, displayID) ->
    return unless @playerName.match(myPlayerIndex+1)
    this[variableName] -= 1
    $(displayID).html(this[variableName])
  addBomb: ->
    @_addItem('numBombs', '#bomb-count')
  removeBomb: ->
    @_removeItem('numBombs', '#bomb-count')
  addShuriken: ->
    @_addItem('numShurikens', '#shuriken-count')
  removeShuriken: ->
    @_removeItem('numShurikens', '#shuriken-count')
  addRadar: ->
    @_addItem('numRadars', '#radar-count')
  removeRadar: ->
    @_removeItem('numRadars', '#radar-count')
  addShield: ->
    @_addItem('numShields', '#shield-count')
  removeShield: ->
    @_removeItem('numShields', '#shield-count')

  update: ->
    if now - @freezeStartTime < 2500
      return

    if @stepsLeft
      @pixelY += @dPixelY
      @pixelX += @dPixelX
      @stepsLeft -= 1
      if @stepsLeft == 0
        @y = @targetY
        @x = @targetX
        @dy = @dx = @dPixelY = @dPixelX = 0

      channel.trigger('move', [myPlayerIndex, [@pixelY, @pixelX]])

  move: (dy, dx) ->
    return false if dy == @dy and dx == @dx
    return false if dy != @dy and dx != @dx
    return false if @targetY + dy < 0 or @targetY + dy == width or
      @targetX + dx < 0 or @targetX + dx == height
    return false if trueMap[@targetY + dy][@targetX + dx]

    unitAtTarget = unitsMap[@targetY + dy][@targetX + dx]
    return false if unitAtTarget != null and
      (@collide(unitAtTarget) or unitAtTarget.collide(this))

    @targetY += dy
    @targetX += dx
    @dy = dy
    @dx = dx
    @dPixelY = GRID_SIZE / @speed * dy
    @dPixelX = GRID_SIZE / @speed * dx
    @stepsLeft = @speed - @stepsLeft

    if dy < 0 and dx == 0
      @direction = UP
    if dy > 0 and dx == 0
      @direction = DOWN
    if dy == 0 and dx < 0
      @direction = LEFT
    if dy == 0 and dx > 0
      @direction = RIGHT

    return true

  drawStatic: (ctx) ->
    ctx.drawImage(sprites[@playerName], @pixelX, @pixelY)


class Item extends Unit
  constructor: (name, y, x) ->
    super(name, y, x)
    @isActive = false

  collide: (unit) ->
    if @isActive
      @_itemCollide(unit)
    else if !@isActive and unit.name == 'player'
      @acquiredBy(unit)
      @dead = true
      channel.trigger('itemAcquired', [myPlayerIndex, @y, @x])
      false

  acquiredBy: (player) ->

  use: (player) ->

class Bomb extends Item
  @image: new Image()
  @explosionImage: new Image()

  constructor: (y, x) ->
    super('bomb', y, x)

  update: ->
    return unless @isActive

    @explode() if now - @startTime > 4000
    return unless @explosionStartTime?

    if now - @explosionStartTime > 1000
      @dead = true
      @user.addBomb()

      destroyedBoxes = []
      if trueMap[@y][@left] == BOX
        destroyedBoxes.push([@y, @left])
      if trueMap[@y][@right] == BOX
        destroyedBoxes.push([@y, @right])
      if trueMap[@top][@x] == BOX
        destroyedBoxes.push([@top, @x])
      if trueMap[@bottom][@x] == BOX
        destroyedBoxes.push([@bottom, @x])

      for [y, x] in destroyedBoxes
        trueMap[y][x] = EMPTY
        if myPlayerIndex == 0
          newItem = randomItem(y, x)
          if newItem
            unitsToAdd.push(newItem)
            channel.trigger('itemAppear', [myPlayerIndex, newItem.name, y, x])

    else
      for unit in units when unit != this
        [y, x] = unit.centerPosition()
        if (y == @y and x >= @left and x <= @right) or (x == @x and y >= @top and y <= @bottom)
          if unit.name == 'bomb' and unit.isActive
            unit.explode()
          else if unit.name == 'player'
            unit.dead = true if now - unit.shieldStartTime > 6000
          else
            unit.dead = true

      
  explode: ->
    return if @explosionStartTime?

    @left = @x
    @right = @x
    @top = @y
    @bottom = @y
    while @left > 0 and Math.abs(@left - @x) < @strength
      terrain = trueMap[@y][@left-1]
      unit = unitsMap[@y][@left-1]
      if terrain == EMPTY or terrain == BOX or unit
        @left -= 1
      if terrain == BRICK or terrain == BOX or unit
        break
    while @right < width - 1 and Math.abs(@right - @x) < @strength
      terrain = trueMap[@y][@right+1]
      unit = unitsMap[@y][@right+1]
      if terrain == EMPTY or terrain == BOX or unit
        @right += 1
      if terrain == BRICK or terrain == BOX or unit
        break
    while @top > 0 and Math.abs(@top - @y) < @strength
      terrain = trueMap[@top-1][@x]
      unit = unitsMap[@top-1][@x]
      if terrain == EMPTY or terrain == BOX or unit
        @top -= 1
      if terrain == BRICK or terrain == BOX or unit
        break
    while @bottom < height - 1 and Math.abs(@bottom - @y) < @strength
      terrain = trueMap[@bottom+1][@x]
      unit = unitsMap[@bottom+1][@x]
      if terrain == EMPTY or terrain == BOX or unit
        @bottom += 1
      if terrain == BRICK or terrain == BOX or unit
        break

    @explosionStartTime = now

    
  acquiredBy: (player) ->
    player.addBomb()

  _itemCollide: (unit) -> true

  use: (player) ->
    units.push this
    unitsMap[@y][@x] = this
    @isActive = true
    @startTime = now

    @user = player
    @strength = player.bombStrength
    player.removeBomb()

  drawStatic: (ctx) ->
    ctx.drawImage(Bomb.image, @pixelX, @pixelY)

  drawAnimated: (ctx) ->
    if @isActive
      if @explosionStartTime?
        ctx.fillStyle = 'red'
        ctx.fillRect(@left * GRID_SIZE, @y * GRID_SIZE,
          (@right - @left + 1) * GRID_SIZE, GRID_SIZE)
        ctx.fillRect(@x * GRID_SIZE, @top * GRID_SIZE,
          GRID_SIZE, (@bottom - @top + 1) * GRID_SIZE)
      else
        @drawStatic(ctx)

        # draw some dots
        ctx.beginPath()
        for i in [0...10]
          y = Math.round(Math.random() * (GRID_SIZE / 2))
          x = Math.round(Math.random() * (GRID_SIZE / 2) + (GRID_SIZE / 2))
          ctx.strokeStyle = 'black'
          ctx.rect(@pixelX + x, @pixelY + y, 1, 1)
          ctx.stroke()

        # draw the timer
        timeLeft = Math.round((4000 - (now - @startTime)) / 100) / 10
        ctx.font = "10pt Arial"
        ctx.strokeStyle = 'white'
        ctx.strokeText(timeLeft, @pixelX, @pixelY + 12)
    else
      @drawStatic(ctx)

class Shuriken extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('shuriken', y, x)
    
  acquiredBy: (player) ->
    player.addShuriken()

  _itemCollide: (unit) -> false

  use: (player) ->
    units.push this
    @isActive = true

    @user = player
    @user.removeShuriken()
    speed = 12

    @dPixelX = 0
    @dPixelY = 0
    if player.direction == UP
      @pixelY = player.pixelY - GRID_SIZE
      @pixelX = player.pixelX
      @dPixelY = -speed
    else if player.direction == DOWN
      @pixelY = player.pixelY + GRID_SIZE
      @pixelX = player.pixelX
      @dPixelY = speed
    else if player.direction == LEFT
      @pixelY = player.pixelY
      @pixelX = player.pixelX - GRID_SIZE
      @dPixelX = -speed
    else if player.direction == RIGHT
      @pixelY = player.pixelY
      @pixelX = player.pixelX + GRID_SIZE
      @dPixelX = speed

  update: ->
    return unless @isActive

    @pixelY += @dPixelY
    @pixelX += @dPixelX
    pixelBottom = @pixelY + GRID_SIZE
    pixelRight = @pixelX + GRID_SIZE
    if @pixelY >= canvasHeight or @pixelX >= canvasWidth or pixelBottom <= 0 or pixelRight <= 0
      @dead = true
      return
    else
      for unit in units when unit.name == 'player' and unit != @user
        continue if unit.pixelX > pixelRight or unit.pixelRight() < @pixelX or unit.pixelY > pixelBottom or unit.pixelBottom() < @pixelY
        unit.freezeStartTime = now
        @dead = true
        break

  drawStatic: (ctx) ->
    ctx.drawImage(Shuriken.image, @pixelX, @pixelY)

  drawAnimated: (ctx) ->
    if @isActive
      ctx.drawImage(Shuriken.image, @pixelX, @pixelY)
    else
      @drawStatic(ctx)

class Radar extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('radar', y, x)

  acquiredBy: (player) ->
    player.addRadar()

  _itemCollide: (unit) -> false

  update: ->
    return unless @isActive

    leftoverReflections = []
    for [[y, x], detectionTime] in @reflections
      if now - detectionTime < 2000
        leftoverReflections.push [[y, x], detectionTime]
    @reflections = leftoverReflections

    if @radius < 800
      @radius += 10

      for unit in units when unit.name == 'player' and not @detected[unit.playerName] and unit != @user
        centerY = unit.pixelY + GRID_SIZE / 2
        centerX = unit.pixelX + GRID_SIZE / 2
        if Math.sqrt(Math.pow(centerY - @centerY, 2) + Math.pow(centerX - @centerX, 2)) <= @radius
          @reflections.push [[centerY, centerX], now]
          @detected[unit.playerName] = 1

    else if @reflections.length == 0
      @dead = true

  use: (player) ->
    units.push this
    @isActive = true
    
    @user = player
    player.removeRadar()
    @radius = 1
    @centerY = player.pixelY + GRID_SIZE / 2
    @centerX = player.pixelX + GRID_SIZE / 2
    @reflections = []
    @detected = {}

  drawStatic: (ctx) ->
    ctx.drawImage(Radar.image, @pixelX, @pixelY)

  drawAnimated: (ctx) ->
    if not @isActive
      @drawStatic ctx
      return

    if @radius < 800
      ctx.strokeStyle = 'black'
      ctx.beginPath()
      ctx.arc(@centerX, @centerY, @radius, 0, 2 * Math.PI, false)
      ctx.stroke()
    for [[y, x], detectionTime] in @reflections
      ctx.fillStyle = 'rgba(255, 0, 0, 0.5)'
      ctx.beginPath()
      ctx.arc(x, y, GRID_SIZE / 4, 0, 2 * Math.PI, false)
      ctx.fill()
    

class Shoe extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('shoe', y, x)

  acquiredBy: (player) ->
    player.speed -= 1 if player.speed > 7

  drawStatic: (ctx) ->
    ctx.drawImage(Shoe.image, @pixelX, @pixelY)


class Glasses extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('glasses', y, x)

  acquiredBy: (player) ->
    player.vision += 1

  drawStatic: (ctx) ->
    ctx.drawImage(Glasses.image, @pixelX, @pixelY)


class Shield extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('shield', y, x)

  acquiredBy: (player) ->
    player.addShield()

  _itemCollide: (unit) -> false

  update: ->
    return unless @isActive

    if now - @user.shieldStartTime > 3000
      @dead = true
    else
      @pixelX = @user.pixelX
      @pixelY = @user.pixelY

  use: (player) ->
    units.push this
    @isActive = true
    
    @user = player
    player.shieldStartTime = now
    player.removeShield()

  drawStatic: (ctx) ->
    ctx.drawImage(Shield.image, @pixelX, @pixelY)


class Explosive extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('explosive', y, x)

  acquiredBy: (player) ->
    player.bombStrength += 1

  _itemCollide: -> false

  drawStatic: (ctx) ->
    ctx.drawImage(Explosive.image, @pixelX, @pixelY)

# event variables
keyDown =
  left: false
  up: false
  right: false
  down: false
keyPresses = {}

   
# global variables
height = 15
width = 15
canvasHeight = null
canvasWidth = null
units = null
unitsToAdd = null
numPlayers = null
trueMap = null
beliefMap = null
unitsMap = null
myPlayerIndex = null
myPlayer = null
myLives = null
canvas = null
gameLoopId = null
socket = null
channel = null

now = null

sprites =
  BOX: new Image()
  BRICK: new Image()
  EMPTY: new Image()
  p1: new Image()
  p2: new Image()
  p3: new Image()
  p4: new Image()


initNetwork = ->
  socket = new WebSocketRails(bootstrap_data.websocketUri, true)

  game_id = bootstrap_data.game.id

  # joining a game
  if bootstrap_data.current_user.id == bootstrap_data.game.player1_id
    myPlayerIndex = 0
  else
    $('#joiner-message').html('joining game')
    socket.on_open = ->
      success = (game) ->
        if game.player2_id == bootstrap_data.current_user.id
          myPlayerIndex = 1
        else if game.player3_id == bootstrap_data.current_user.id
          myPlayerIndex = 2
        else if game.player4_id == bootstrap_data.current_user.id
          myPlayerIndex = 3
        $('#joiner-message').show().html("Joined game as player #{myPlayerIndex+1}, waiting for host to start game...")
      failed = (message) ->
        $('#joiner-message').show().html("Failed to join game: #{message}")
      socket.trigger('games.join', game_id, success, failed)

  # starting a game
  $('#start-game, #restart-game').click ->
    failed = (message) ->
      alert "Failed to start game: #{message}"

    #initialize map
    gameMap = []
    for i in [0...height]
      row = (EMPTY for j in [0...width])
      if i % 2
        row[j] = BRICK for j in [1...width] by 2
      gameMap.push row
    for y in [0...height]
      for x in [0...width]
        gameMap[y][x] = BOX if Math.random() < 0.6 and gameMap[y][x] == EMPTY
    gameMap[0][0] = EMPTY
    gameMap[0][1] = EMPTY
    gameMap[1][0] = EMPTY
    gameMap[height-1][0] = EMPTY
    gameMap[height-1][1] = EMPTY
    gameMap[height-2][0] = EMPTY
    gameMap[0][width-1] = EMPTY
    gameMap[0][width-2] = EMPTY
    gameMap[1][width-1] = EMPTY
    gameMap[height-1][width-1] = EMPTY
    gameMap[height-1][width-2] = EMPTY
    gameMap[height-2][width-1] = EMPTY

    socket.trigger('games.start', {id: game_id, map: gameMap}, null, failed)

  # join the channel for this game
  channel = socket.subscribe("game_#{game_id}")
  channel.bind 'start', (gameMap) ->
    $('#start-game').hide()
    $('#joiner-message').hide()
    $('#restart-game').show()
    $('#items-count').show()
    $('#players-list').hide()
    initGame(gameMap)

  channel.bind 'move', unitMove
  channel.bind 'itemAppear', itemAppear
  channel.bind 'itemAcquired', itemAcquired
  channel.bind 'itemUse', itemUse
  channel.bind 'imdead', killUser
  channel.bind 'playerJoined', playerJoined

  # attach key events handlers (technically doesn't belong here, but whatever)
  $('body').keydown((e) ->
    if e.which == 37
      keyDown.left = true
    else if e.which == 38
      keyDown.up = true
    else if e.which == 39
      keyDown.right = true
    else if e.which == 40
      keyDown.down = true
  ).keyup((e) ->
    if e.which == 37
      keyDown.left = false
    else if e.which == 38
      keyDown.up = false
    else if e.which == 39
      keyDown.right = false
    else if e.which == 40
      keyDown.down = false
  ).keypress((e) ->
    if e.which >= 48 and e.which <= 57
      keyPresses[e.which - 48] = true
  )


initGame = (gameMap) ->
  trueMap = gameMap  
  beliefMap = $.extend(true, [], trueMap)

  unitsMap = ((null for x in [0...width]) for y in [0...height])

  # initialize units
  units = [
    new Player('p1', 0, 0),
    new Player('p2', height-1, 0),
    new Player('p3', 0, width-1),
    new Player('p4', height-1, width-1)
  ]
  myPlayer = units[myPlayerIndex]
  myLives = 3
  numPlayers = $('#players-list li').size()
  unitsToAdd = []
  
  # initialize drawing
  canvasHeight = height * GRID_SIZE
  canvasWidth = width * GRID_SIZE
  canvas = $('#game')[0]
  canvas.height = canvasHeight
  canvas.width = canvasWidth

  # load sprites
  Bomb.image.src = '/assets/bomb.png'
  Bomb.explosionImage.src = '/assets/explosion.png'
  Radar.image.src = '/assets/radar.png'
  Shuriken.image.src = '/assets/shuriken.png'
  Shoe.image.src = '/assets/shoe.png'
  Glasses.image.src = '/assets/glasses.png'
  Shield.image.src = '/assets/shield.png'
  Explosive.image.src = '/assets/explosive.png'

  sprites.BOX.src = '/assets/box.png'
  sprites.BRICK.src = '/assets/brick.png'
  sprites.EMPTY.src = '/assets/grass.png'

  sprites.p1.src = '/assets/player1.png'
  sprites.p2.src = '/assets/player2.png'
  sprites.p3.src = '/assets/player3.png'
  sprites.p4.src = '/assets/player4.png'

  # start game loop
  gameLoop()
  clearInterval(gameLoopId)
  gameLoopId = setInterval(gameLoop, 25)


gameLoop = ->
  now = new Date().getTime()
  readInputs()
  updateGame()
  drawGame()

readInputs = ->
  return if myLives == 0

  moved = false
  if keyDown.left
    moved = myPlayer.move(0, -1)
  else if keyDown.up
    moved = myPlayer.move(-1, 0)
  else if keyDown.right
    moved = myPlayer.move(0, 1)
  else if keyDown.down
    moved = myPlayer.move(1, 0)

  [centerY, centerX] = myPlayer.centerPosition()
  if unitsMap[centerY][centerX] == null
    if keyPresses[1] and myPlayer.numBombs
      new Bomb(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'bomb', centerY, centerX, myPlayer.bombStrength])
    else if keyPresses[2] and myPlayer.numShurikens
      new Shuriken(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'shuriken', centerY, centerX, myPlayer.direction])
    else if keyPresses[3] and myPlayer.numRadars
      new Radar(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'radar', centerY, centerX])
    else if keyPresses[4] and myPlayer.numShields
      new Shield(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'shield', centerY, centerX])


updateGame = ->
  for unit in units
    unit.update()

  aliveUnits = []
  for u in units
    if not u.dead
      aliveUnits.push(u)
    else if u.name != 'player'
      unitsMap[u.y][u.x] = null
    else if u.playerName != myPlayer.playerName
      # another player died so don't remove him, wait for his "I'm dead" message
      unless u.reallyDead
        aliveUnits.push(u)
      else if u.playerName < myPlayer.playerName
        myPlayerIndex--
    else
      # respawn self if has lives left
      myLives--
      $('#live-count > img:first').remove()
      if myLives > 0
        # just create a new player and give it a temporary shield
        myNewPlayer = new Player(myPlayer.playerName, myPlayer.startingY, myPlayer.startingX, 12)
        myNewPlayer.shieldStartTime = now
        myNewPlayer.numBombs = myPlayer.numBombs
        myNewPlayer.numShields = myPlayer.numShields
        myNewPlayer.numRadars = myPlayer.numRadars
        myNewPlayer.numShurikens = myPlayer.numShurikens
        aliveUnits.push(myNewPlayer)
        unitsMap[myNewPlayer.y][myNewPlayer.x] = myNewPlayer
      else
        channel.trigger('imdead', myPlayerIndex)
        socket.trigger('games.lost')
        alert 'You got pwned!!'

  units = aliveUnits

  for unit in unitsToAdd
    units.push(unit)
    unitsMap[unit.y][unit.x] = unit
  unitsToAdd = []

  keyPresses = {}

drawGame = ->
  ctx = canvas.getContext('2d')
  ctx.clearRect(0, 0, canvasWidth, canvasHeight)

  [myY, myX] = myPlayer.centerPosition()

  # draw map
  for y in [0...height]
    for x in [0...width]
      outsideVision = true
      if myLives == 0 or Math.abs(y - myY) + Math.abs(x - myX) < myPlayer.vision
        beliefMap[y][x] = trueMap[y][x]
        outsideVision = false

      if beliefMap[y][x] == EMPTY
        ctx.drawImage(sprites.EMPTY, x * GRID_SIZE, y * GRID_SIZE)
      else if beliefMap[y][x] == BRICK
        ctx.drawImage(sprites.BRICK, x * GRID_SIZE, y * GRID_SIZE)
      else if beliefMap[y][x] == BOX
        ctx.drawImage(sprites.BOX, x * GRID_SIZE, y * GRID_SIZE)

      if outsideVision
        ctx.fillStyle = 'rgba(64, 64, 64, 0.7)'
        ctx.fillRect(x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)


  # draw units
  for unit in units
    [y, x] = unit.centerPosition()
    if myLives == 0 or Math.abs(y - myY) + Math.abs(x - myX) < myPlayer.vision or (unit.name == 'bomb' and unit.explosionStartTime?)
      unit.drawAnimated(ctx) 


randomItem = (y, x) ->
  return null if Math.random() < 0.2

  weights = [
    [Bomb, 100]
    [Shuriken, 100]
    [Radar, 100]
    [Shoe, 100]
    [Glasses, 60]
    [Shield, 75]
    [Explosive, 100]
  ]
  totalWeight = 0
  for [klass, weight] in weights
    totalWeight += weight

  roll = Math.random()
  for [klass, weight] in weights
    p = weight / totalWeight
    if roll < p
      return new klass(y, x)
   
    roll -= p


playerJoined = (message) ->
  $('#players-list > ol').append("<li>#{message}</li>")

unitMove = (message) ->
  playerIndex = message[0]
  return if playerIndex == myPlayerIndex
  [pixelY, pixelX] = message[1]
  units[playerIndex].pixelY = pixelY
  units[playerIndex].pixelX = pixelX

itemAppear = (message) ->
  [playerIndex, itemName, y, x] = message
  return if playerIndex == myPlayerIndex
  if itemName == 'bomb'
    unitsToAdd.push(new Bomb(y, x))
  else if itemName == 'shuriken'
    unitsToAdd.push(new Shuriken(y, x))
  else if itemName == 'radar'
    unitsToAdd.push(new Radar(y, x))
  else if itemName == 'shoe'
    unitsToAdd.push(new Shoe(y, x))
  else if itemName == 'glasses'
    unitsToAdd.push(new Glasses(y, x))
  else if itemName == 'shield'
    unitsToAdd.push(new Shield(y, x))
  else if itemName == 'explosive'
    unitsToAdd.push(new Explosive(y, x))

itemAcquired = (message) ->
  [playerIndex, y, x] = message
  return if playerIndex == myPlayerIndex
  unit = unitsMap[y][x]
  return unless unit
  unit.dead = true

itemUse = (message) ->
  [playerIndex, itemName, y, x] = message
  return if playerIndex == myPlayerIndex

  player = units[playerIndex]

  if itemName == 'bomb'
    player.bombStrength = message[4]
    new Bomb(y, x).use(player)
  else if itemName == 'shuriken'
    player.direction = message[4]
    new Shuriken(y, x).use(player)
  else if itemName == 'radar'
    new Radar(y, x).use(player)
  else if itemName == 'shield'
    new Shield(y, x).use(player)

killUser = (playerIndex) ->
  return if playerIndex == myPlayerIndex
  units[playerIndex].dead = true
  units[playerIndex].reallyDead = true

  # if I haven't lost yet and am the last one standing, I won!
  numPlayers -= 1
  if numPlayers == 1 and myLives > 0
    socket.trigger('games.won')
    alert 'You won!'
