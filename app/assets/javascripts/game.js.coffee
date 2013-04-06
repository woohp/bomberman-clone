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
  constructor: (@playerName, y, x, @speed) ->
    super('player', y, x)

    # vision
    @vision = 7

    # items related
    @numBombs = 1
    @numShurikens = 1
    @numRadars = 1
    @bombStrength = 3

    # movement related variables
    @canMove = true
    @targetY = y
    @targetX = x
    @dy = 0
    @dx = 0
    @dPixelY = 0
    @dPixelX = 0
    @stepsLeft = 0
    @direction = DOWN

  pixelBottom: -> @pixelY + GRID_SIZE
  pixelRight: -> @pixelX + GRID_SIZE

  update: ->
    now = new Date().getTime()
    if @freezeStartTime?
      if now - @freezeStartTime > 2000
        @freezeStartTime = null
      return

    if @stepsLeft and @canMove
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
    ctx.beginPath()
    ctx.strokeStyle = 'white'
    ctx.rect(@pixelX, @pixelY, GRID_SIZE, GRID_SIZE)
    ctx.stroke()


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

  constructor: (y, x) ->
    super('bomb', y, x)

  update: ->
    return unless @isActive

    now = new Date().getTime()
    if now - @startTime > 4000
      @explode()

    return unless @explosionStartTime?

    if now - @explosionStartTime > 1000
      @dead = true
      @user.numBombs += 1

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

    @explosionStartTime = new Date().getTime()

    
  acquiredBy: (player) ->
    player.numBombs += 1

  _itemCollide: (unit) -> true

  use: (player) ->
    units.push this
    unitsMap[@y][@x] = this
    @isActive = true
    @startTime = new Date().getTime()

    @user = player
    @strength = player.bombStrength
    player.numBombs -= 1

  drawStatic: (ctx) ->
    ctx.drawImage(Bomb.image, @x * GRID_SIZE, @y * GRID_SIZE)

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
    else
      @drawStatic(ctx)

class Shuriken extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('shuriken', y, x)
    
  acquiredBy: (player) ->
    player.numShurikens += 1

  _itemCollide: (unit) -> false

  use: (player) ->
    units.push this
    @isActive = true

    @user = player
    @user.numShurikens -= 1
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
        unit.freezeStartTime = new Date().getTime()
        @dead = true
        break

  drawStatic: (ctx) ->
    ctx.drawImage(Shuriken.image, @x * GRID_SIZE, @y * GRID_SIZE)

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
    player.numRadars += 1

  _itemCollide: (unit) -> false

  update: ->
    return unless @isActive

    now = new Date().getTime()
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
    player.numRadars -= 1
    @radius = 1
    @centerY = player.pixelY + GRID_SIZE / 2
    @centerX = player.pixelX + GRID_SIZE / 2
    @reflections = []
    @detected = {}

  drawStatic: (ctx) ->
    ctx.drawImage(Radar.image, @x * GRID_SIZE, @y * GRID_SIZE)

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
    player.speed += 1

  drawStatic: (ctx) ->
    ctx.drawImage(Shoe.image, @x * GRID_SIZE, @y * GRID_SIZE)


class Glasses extends Item
  @image: new Image()

  constructor: (y, x) ->
    super('glasses', y, x)

  acquiredBy: (player) ->
    player.vision += 1

  drawStatic: (ctx) ->
    ctx.drawImage(Glasses.image, @x * GRID_SIZE, @y * GRID_SIZE)


# event variables
keyDown =
  left: false
  up: false
  right: false
  down: false
keyPresses = {}

   
# global variables
height = 11
width = 11
canvasHeight = null
canvasWidth = null
units = null
unitsToAdd = null
trueMap = null
beliefMap = null
unitsMap = null
myPlayerIndex = null
myPlayer = null
canvas = null
gameLoopId = null
socket = null
channel = null


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
        $('#joiner-message').html("Joined game as player #{myPlayerIndex+1}, waiting for host to start game...")
      failed = (message) ->
        $('#joiner-message').html("Failed to join game: #{message}")
      socket.trigger('games.join', game_id, success, failed)

  # starting a game
  $('#start-game').click ->
    failed = (message) ->
      alert "Failed to start game: #{message}"

    #initialize map
    gameMap = [
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    ]
    for y in [0...height] by 1
      for x in [0...width] by 1
        gameMap[y][x] = BOX if Math.random() < 0.3 and gameMap[y][x] == EMPTY
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

  channel = socket.subscribe("game_#{game_id}")
  channel.bind 'start', (gameMap) ->
    $('#start-game').hide()
    $('#joiner-message').hide()
    initGame(gameMap)

  channel.bind 'move', unitMove
  channel.bind 'itemAppear', itemAppear
  channel.bind 'itemAcquired', itemAcquired
  channel.bind 'itemUse', itemUse


initGame = (gameMap) ->
  trueMap = gameMap  
  beliefMap = $.extend(true, [], trueMap)

  unitsMap = ((null for x in [0...width]) for y in [0...height])

  # initialize units
  units = [
    new Player('p1', 0, 0, 12),
    new Player('p2', height-1, 0, 12),
    new Player('p3', 0, width-1, 12),
    new Player('p4', height-1, width-1, 12)
  ]
  myPlayer = units[myPlayerIndex]

  bomb = new Bomb(1, 0)
  units.push(bomb)
  unitsMap[1][0] = bomb
  unitsToAdd = []

  
  # attach event handlers
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

  # initialize drawing
  canvasHeight = height * GRID_SIZE
  canvasWidth = width * GRID_SIZE
  canvas = $('#game')[0]
  canvas.height = canvasHeight
  canvas.width = canvasWidth

  Bomb.image.src = '/assets/bomb.png'
  Radar.image.src = '/assets/radar.png'
  Shuriken.image.src = '/assets/shuriken.png'

  # start game loop
  gameLoop()
  gameLoopId = setInterval(gameLoop, 25)


gameLoop = ->
  readInputs()
  updateGame()
  drawGame()

readInputs = ->
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
      channel.trigger('itemUse', [myPlayerIndex, 'bomb', centerY, centerX])
    else if keyPresses[2] and myPlayer.numShurikens
      new Shuriken(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'shuriken', centerY, centerX, myPlayer.direction])
    else if keyPresses[3] and myPlayer.numRadars
      new Radar(centerY, centerX).use(myPlayer)
      channel.trigger('itemUse', [myPlayerIndex, 'radar', centerY, centerX])


updateGame = ->
  for unit in units
    unit.update()

  aliveUnits = []
  for u in units
    if u.dead
      unitsMap[u.y][u.x] = null
    else
      aliveUnits.push(u)
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
      if Math.abs(y - myY) + Math.abs(x - myX) < myPlayer.vision
        beliefMap[y][x] = trueMap[y][x]
        outsideVision = false

      if beliefMap[y][x] == EMPTY
        ctx.fillStyle = 'green'
      else if beliefMap[y][x] == BRICK
        ctx.fillStyle = 'gray'
      else if beliefMap[y][x] == BOX
        ctx.fillStyle = 'BurlyWood'
      ctx.fillRect(x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)

      if outsideVision
        ctx.fillStyle = 'rgba(64, 64, 64, 0.35)'
        ctx.fillRect(x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)


  # draw units
  for unit in units
    [y, x] = unit.centerPosition()
    if Math.abs(y - myY) + Math.abs(x - myX) < myPlayer.vision or (unit.name == 'bomb' and unit.explosionStartTime?)
      unit.drawAnimated(ctx) 


randomItem = (y, x) ->
  probabilities = [
    [Bomb, 0.13]
    [Shuriken, 0.13]
    [Radar, 0.13]
    [Shoe, 0.13]
    [Shoe, 0.08]
  ]

  roll = Math.random()
  for [klass, p] in probabilities
    if roll < p
      return new klass(y, x)
   
    roll -= p

  return null


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
  if itemName == 'shuriken'
    unitsToAdd.push(new Shuriken(y, x))
  if itemName == 'radar'
    unitsToAdd.push(new Radar(y, x))
  if itemName == 'shoe'
    unitsToAdd.push(new Shoe(y, x))
  if itemName == 'glasses'
    unitsToAdd.push(new Glasses(y, x))

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
    new Bomb(y, x).use(player)
  else if itemName == 'shuriken'
    direction = message[4]
    player.direction = direction
    new Shuriken(y, x).use(player)
  else if itemName == 'radar'
    new Radar(y, x).use(player)
