local bump = require "vendor.bump"
local camera = require "camera"

local CAMERA_SPEED = 75
local GRAVITY = 981 -- pixels per second^2
local METROID_SCALE = 0.5
local PLAYER_SCALE = 1.0
local PLAYER_ACC_RUN = 200
local PLAYER_ACC_BRAKE = 2000
local PLAYER_ACC_JUMP = 600
local LEVEL_WIDTH = love.graphics.getWidth()
local LEVEL_HEIGHT = love.graphics.getHeight()
local STATE_RUNNING = 1
local STATE_PAUSED = 2
local STATE_WON = 3
local STATE_GAMEOVER = 4
local TIME_TO_ESCAPE = 30 -- seconds

local game = {
  state = STATE_PAUSED,
  time = 0,
  timeLastSpawn = 0,
}
local world
local objects = {}
local resources = {
  gfx = {},
  sfx = {},
}
local colors = { -- SLSO-CLR17 17 Color Palette
  ["#2e2c3b"] = {46/255, 44/255, 59/255},
  ["#3e415f"] = {62/255, 65/255, 95/255},
  ["#55607d"] = {85/255, 96/255, 125/255},
  ["#747d88"] = {116/255, 125/255, 136/255},
  ["#41de95"] = {65/255, 222/255, 149/255},
  ["#2aa4aa"] = {42/255, 164/255, 170/255},
  ["#3b77a6"] = {59/255, 119/255, 166/255},
  ["#249337"] = {36/255, 147/255, 55/255},
  ["#56be44"] = {86/255, 190/255, 68/255},
  ["#c6de78"] = {198/255, 222/255, 120/255},
  ["#f3c220"] = {243/255, 194/255, 32/255},
  ["#c4651c"] = {196/255, 101/255, 28/255},
  ["#b54131"] = {181/255, 65/255, 49/255},
  ["#61407a"] = {97/255, 64/255, 122/255},
  ["#8f3da7"] = {143/255, 61/255, 167/255},
  ["#ea619d"] = {234/255, 97/255, 157/255},
  ["#c1e5ea"] = {193/255, 229/255, 234/255},
}

function love.load(arg)
  love.graphics.setDefaultFilter('nearest', 'nearest')

  -- load images only once
  resources.gfx.metroid = love.graphics.newImage("gfx/metroid.png")
  resources.gfx.player = love.graphics.newImage("gfx/player.png")
  resources.sfx.levelsound = love.audio.newSource("sfx/level_sound.wav", "static")
  resources.sfx.jump = love.audio.newSource("sfx/jump.wav", "static")

  world = bump.newWorld(64) -- cell size = 64

  -- level boundaries
  objects.borders = {
    left = {type = "border_l", x = 0, y = 0, w = 1, h = LEVEL_HEIGHT},
    right = {type = "border_r", x = LEVEL_WIDTH - 1, y = 0, w = 1, h = LEVEL_HEIGHT},
  }
  addWorldObject(objects.borders.left)
  addWorldObject(objects.borders.right)

  -- ground
  objects.ground = {type = "ground", x = 0, y = LEVEL_HEIGHT - 48, w = LEVEL_WIDTH * 100, h = 48}
  addWorldObject(objects.ground)
  camera:newLayer(1, function()
    love.graphics.setColor(colors["#61407a"])
    love.graphics.rectangle("fill", objects.ground.x, objects.ground.y, objects.ground.w, objects.ground.h)
  end)

  -- player
  objects.player = {
    type = "player",
    x = 128,
    y = objects.ground.y - resources.gfx.player:getHeight(),
    w = resources.gfx.player:getWidth() * PLAYER_SCALE,
    h = resources.gfx.player:getHeight() * PLAYER_SCALE,
    vx = 0,
    vy = 0,
    acc_run = PLAYER_ACC_RUN,
    acc_brake = PLAYER_ACC_BRAKE,
    acc_jump = PLAYER_ACC_JUMP
  }
  addWorldObject(objects.player)
  camera:newLayer(1, function()
    love.graphics.setColor(colors["#f3c220"])
    love.graphics.draw(resources.gfx.player, objects.player.x, objects.player.y, 0, PLAYER_SCALE)
  end)

  -- metroids
  objects.metroids = {}
  camera:newLayer(1, function()
    for i, item in ipairs(objects.metroids) do
      love.graphics.setColor(colors["#249337"])
      love.graphics.draw(resources.gfx.metroid, item.x, item.y, 0, METROID_SCALE)
    end
  end)

  resources.sfx.levelsound:setLooping(true)
  resources.sfx.levelsound:play()
end

function love.update(dt)
  if STATE_RUNNING ~= game.state then
    return
  end

  game.time = game.time + dt

  -- check for winning condition
  if game.time > TIME_TO_ESCAPE then
    game.state = STATE_WON
    return
  end

  -- add 1-3 new metroids every 2 seconds
  if game.time > game.timeLastSpawn + 2 then
    game.timeLastSpawn = game.time
    for i = 1, love.math.random(1, 3) do
      addMetroid()
    end
  end

  updateLeftBorder(objects.borders.left)
  updateRightBorder(objects.borders.right)
  updatePlayer(objects.player, dt)
  for i, metroid in ipairs(objects.metroids) do
    updateMetroid(metroid, dt, i)
  end

  camera:move(CAMERA_SPEED * dt, 0)
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setBackgroundColor(colors["#2e2c3b"])

  camera:draw()

  love.graphics.setColor(colors["#c1e5ea"])
  love.graphics.print(string.format('FPS: %s Time: %s', love.timer.getFPS(), (math.floor(game.time * 10) * 0.1)), 2, 2)

  if STATE_PAUSED == game.state then
    drawTextCentered("ESCAPE THE METROIDS\nPress <space> to play.", { 1, 1, 1 })
  end

  if STATE_GAMEOVER == game.state then
    drawTextCentered("GAME OVER\nPress <r> to restart.", { 1, 1, 1 })
  end

  if STATE_WON == game.state then
    drawTextCentered("CONGRATULATIONS\nYou escaped the metroids.\nPress <r> to restart.", { 1, 1, 1 })
  end
end

function love.keypressed(key, scancode, isrepeat)
  if 'space' == key and STATE_RUNNING == game.state then
    game.state = STATE_PAUSED
  elseif 'space' == key and STATE_PAUSED == game.state then
    game.state = STATE_RUNNING
  end

  if 'r' == key then
    love.event.quit("restart")
  end

  if 'escape' == key then
    love.event.quit()
  end
end

function love.keyreleased(key, scancode)

end

function addWorldObject(object)
  world:add(object, object.x, object.y, object.w, object.h)
end

function addMetroid()
  local metroid = {
    type = "metroid",
    x = love.math.random(camera.x, camera.x + LEVEL_WIDTH),
    y = love.math.random(camera.y, camera.y + LEVEL_HEIGHT / 5),
    w = resources.gfx.metroid:getWidth() * METROID_SCALE,
    h = resources.gfx.metroid:getHeight() * METROID_SCALE,
    vx = 0,
    vy = 0,
    acc = love.math.random(200, 500),
    volatile = false -- (50 >= love.math.random(1, 100)) -- 50% chance for metroid to be destroyed when touching ground
  }
  table.insert(objects.metroids, metroid)
  addWorldObject(metroid)
end

function removeMetroid(i)
  local metroid = objects.metroids[i]
  table.remove(objects.metroids, i)
  world:remove(metroid)
end

function updatePlayer(self, dt)
  if love.keyboard.isDown("right") then
    self.vx = self.vx + dt * (self.vx < 0 and self.acc_brake or self.acc_run)
  elseif love.keyboard.isDown("left") then
    self.vx = self.vx - dt * (self.vx > 0 and self.acc_brake or self.acc_run)
  else
    local brake = dt * (self.vx < 0 and self.acc_brake or -self.acc_brake)
    if math.abs(brake) > math.abs(self.vx) then
      self.vx = 0
    else
      self.vx = self.vx + brake
    end
  end

  if love.keyboard.isDown("up") then
    if 0 == self.vy then
      self.vy = -self.acc_jump
      resources.sfx.jump:play()
    end
  end

  if 0 ~= self.vy then
    self.vy = self.vy + GRAVITY * dt
  end

  local future_x = self.x + CAMERA_SPEED * dt + self.vx * dt -- need to add CAMERA_SPEED * dt to be consistent with camera movement for now
  local future_y = self.y + self.vy * dt

  local next_x, next_y, cols, len = world:move(self, future_x, future_y, function(item, other)
    -- return values must be "touch", "cross", "slide", "bounce" or nil
    if "ground" == other.type then return "slide"
    elseif "border_l" == other.type or "border_r" == other.type then return "bounce"
    elseif "metroid" == other.type then return "touch"
    else return nil end
  end)
  for i, col in ipairs(cols) do
    -- GAME OVER when player touches a metroid
    if "metroid" == col.other.type then
      game.state = STATE_GAMEOVER
    end

    -- bounce player from left screen edge
    if "border_l" == col.other.type then
      self.vx = -self.vx / 2
      if col.touch.x <= col.other.x + col.other.w then
        next_x = col.other.x + col.other.w + 8
        world:update(self, next_x, next_y)
      end
    end

    -- bounce player from right screen edge
    if "border_r" == col.other.type then
      self.vx = -self.vx / 2
      if col.touch.x + col.item.w >= col.other.x then
        next_x = col.other.x - col.item.w - 8
        world:update(self, next_x, next_y)
      end
    end

    -- stop jumping when player touches the ground
    if "ground" == col.other.type and (col.normal.y < 0 and self.vy > 0) then
      self.vy = 0
    end
  end

  self.x, self.y = next_x, next_y
end

function updateMetroid(self, dt, i)
  self.vy = self.vy + dt * self.acc

  local future_x = self.x + self.vx * dt
  local future_y = self.y + self.vy * dt

  local next_x, next_y, cols, len = world:move(self, future_x, future_y)
  for i, col in ipairs(cols) do
    -- GAME OVER when player touches a metroid
    if "player" == col.other.type then
      game.state = STATE_GAMEOVER
    end

    if "ground" == col.other.type and self.volatile then
      removeMetroid(i)
    end
  end

  self.x, self.y = next_x, next_y
end

function updateLeftBorder(self, dt)
  self.x = camera.x
  world:update(self, camera.x, camera.y)
end

function updateRightBorder(self, dt)
  self.x = camera.x + LEVEL_WIDTH - 1
  world:update(self, camera.x + LEVEL_WIDTH - 1, camera.y)
end

function drawTextCentered(text, color)
  love.graphics.push()
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(text, LEVEL_WIDTH)
    local x, y = 0, LEVEL_HEIGHT / 2 - font:getHeight() * #lines / 2

    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, LEVEL_WIDTH, "center")
  love.graphics.pop()
end
