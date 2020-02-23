local bump = require "vendor.bump"
local camera = require "camera"

local CAMERA_SPEED = 75
local ACC_GRAVITY = 500 -- pixels per second^2
local LEVEL_WIDTH = love.graphics.getWidth()
local LEVEL_HEIGHT = love.graphics.getHeight()
local STATE_RUNNING = 1
local STATE_PAUSED = 2
local STATE_WON = 3
local STATE_GAMEOVER = 4

local game = {
  state = STATE_PAUSED,
  time = 0,
  timeLastSpawn = 0,
}
local world
local objects = {}
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
  world = bump.newWorld(64) -- cell size = 64

  -- level boundaries
  objects.borders = {
    left = {type = "border_l", x = 0, y = 0, w = 1, h = LEVEL_HEIGHT},
    right = {type = "border_r", x = LEVEL_WIDTH - 1, y = 0, w = 1, h = LEVEL_HEIGHT},
  }
  world:add(objects.borders.left, objects.borders.left.x, objects.borders.left.y, objects.borders.left.w, objects.borders.left.h)
  world:add(objects.borders.right, objects.borders.right.x, objects.borders.right.y, objects.borders.right.w, objects.borders.right.h)

  -- ground
  objects.ground = {type = "ground", x = 0, y = LEVEL_HEIGHT - 48, w = LEVEL_WIDTH * 100, h = 48}
  world:add(objects.ground, objects.ground.x, objects.ground.y, objects.ground.w, objects.ground.h)
  camera:newLayer(1, function()
    love.graphics.setColor(colors["#61407a"])
    love.graphics.rectangle("fill", objects.ground.x, objects.ground.y, objects.ground.w, objects.ground.h)
  end)

  -- player
  objects.player = {type = "player", x = 128, y = LEVEL_HEIGHT - 2*48, w = 96, h = 48, vx = 0, vy = 0, acc_run = 200, acc_jump = 400}
  world:add(objects.player, objects.player.x, objects.player.y, objects.player.w, objects.player.h)
  camera:newLayer(1, function()
    love.graphics.setColor(colors["#f3c220"])
    love.graphics.rectangle("fill", objects.player.x, objects.player.y, objects.player.w, objects.player.h)
  end)

  -- metroids
  objects.metroids = {}
  camera:newLayer(1, function()
    for i, item in ipairs(objects.metroids) do
      love.graphics.setColor(colors["#249337"])
      love.graphics.rectangle("fill", item.x, item.y, item.w, item.h)
    end
  end)
end

function love.update(dt)
  if STATE_RUNNING ~= game.state then
    return
  end

  game.time = game.time + dt

  -- add 1-3 new metroids every 2 seconds
  if game.time > game.timeLastSpawn + 2 then
    game.timeLastSpawn = game.time
    for i = 1, love.math.random(1, 3) do
      addMetroid()
    end
  end

  objects.borders.left.x = camera.x
  objects.borders.right.x = camera.x + LEVEL_WIDTH - 1
  world:update(objects.borders.left, camera.x, camera.y)
  world:update(objects.borders.right, camera.x + LEVEL_WIDTH - 1, camera.y)

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
    drawTextCentered('Press <space> to play.', { 1, 1, 1 })
  end

  if STATE_GAMEOVER == game.state then
    drawTextCentered('GAME OVER', { 1, 1, 1 })
  end
end

function love.keypressed(key, scancode, isrepeat)
  if 'space' == key and STATE_RUNNING == game.state then
    game.state = STATE_PAUSED
  elseif 'space' == key and STATE_PAUSED == game.state then
    game.state = STATE_RUNNING
  end

  if 'escape' == key then
    love.event.quit()
  end
end

function love.keyreleased(key, scancode)

end

function addMetroid()
  local metroid = {
    type = "metroid",
    x = love.math.random(camera.x, camera.x + LEVEL_WIDTH),
    y = love.math.random(camera.y, camera.y + LEVEL_HEIGHT / 5),
    w = 32,
    h = 32,
    vx = 0,
    vy = 0,
    acc = love.math.random(200, 500),
    volatile = (50 >= love.math.random(1, 100)) -- 50% chance for metroid to be destroyed when touching ground
  }
  table.insert(objects.metroids, metroid)
  world:add(metroid, metroid.x, metroid.y, metroid.w, metroid.h)
end

function removeMetroid(i)
  local metroid = objects.metroids[i]
  table.remove(objects.metroids, i)
  world:remove(metroid)
end

function updatePlayer(self, dt)
  if love.keyboard.isDown("right") then
    self.vx = self.vx + dt * self.acc_run
  elseif love.keyboard.isDown("left") then
    self.vx = self.vx - dt * self.acc_run
  else
    self.vx = 0
  end

  if love.keyboard.isDown("up") then
    if 0 == self.vy then
      self.vy = -self.acc_jump
    end
  end

  if 0 ~= self.vy then
    self.vy = self.vy + ACC_GRAVITY * dt
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
      self.vx = -self.vx
      if col.touch.x <= col.other.x + col.other.w then
        next_x = col.other.x + col.other.w + 16
        world:update(self, next_x, next_y)
      end
    end

    -- bounce player from right screen edge
    if "border_r" == col.other.type then
      self.vx = -self.vx
      if col.touch.x + col.item.w >= col.other.x then
        next_x = col.other.x - col.item.w - 16
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

function drawTextCentered(text, color)
  love.graphics.push()
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(text, LEVEL_WIDTH)
    local x, y = 0, LEVEL_HEIGHT / 2 - font:getHeight() * #lines / 2

    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, LEVEL_WIDTH, "center")
  love.graphics.pop()
end
