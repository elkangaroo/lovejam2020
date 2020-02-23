local bump = require "vendor.bump"
local camera = require "camera"
local game = {
  isPaused = true,
  timer = 0,
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

local CAMERA_SPEED = 75
local ACC_GRAVITY = 500 -- pixels per second^2
local LEVEL_WIDTH = love.graphics.getWidth()
local LEVEL_HEIGHT = love.graphics.getHeight()

function love.load(arg)
  world = bump.newWorld(64) -- cell size = 64

  -- level boundaries
  objects.borders = {
    top = {type = "border", x = 0, y = 0, w = LEVEL_WIDTH, h = 1},
    left = {type = "border", x = 0, y = 0, w = 1, h = LEVEL_HEIGHT},
    right = {type = "border", x = LEVEL_WIDTH - 1, y = 0, w = 1, h = LEVEL_HEIGHT},
  }
  world:add(objects.borders.top, objects.borders.top.x, objects.borders.top.y, objects.borders.top.w, objects.borders.top.h)
  world:add(objects.borders.left, objects.borders.left.x, objects.borders.left.y, objects.borders.left.w, objects.borders.left.h)
  world:add(objects.borders.right, objects.borders.right.x, objects.borders.right.y, objects.borders.right.w, objects.borders.right.h)
  camera:newLayer(1, function()
    for i, item in pairs(objects.borders) do
      love.graphics.setColor(colors["#c1e5ea"])
      love.graphics.rectangle("fill", item.x, item.y, item.w, item.h)
    end
  end)

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
  if game.isPaused then
    return
  end

  game.timer = game.timer + dt

  camera:move(CAMERA_SPEED * dt, 0)

  -- sometimes add new metroids
  if 0 == (math.floor(game.timer * 100) * 0.01) % 2 then
    addMetroid()
  end

  objects.borders.top.x = camera.x
  objects.borders.left.x = camera.x
  objects.borders.right.x = camera.x + LEVEL_WIDTH - 1
  world:update(objects.borders.top, camera.x, camera.y)
  world:update(objects.borders.left, camera.x, camera.y)
  world:update(objects.borders.right, camera.x + LEVEL_WIDTH - 1, camera.y)

  updatePlayer(objects.player, dt)
  for i, metroid in ipairs(objects.metroids) do
    updateMetroid(metroid, dt, i)
  end
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setBackgroundColor(colors["#2e2c3b"])

  camera:draw()

  love.graphics.setColor(colors["#c1e5ea"])
  love.graphics.print(string.format('FPS: %s Time: %s', love.timer.getFPS(), (math.floor(game.timer * 10) * 0.1)), 2, 2)

  if game.isPaused then
    drawTextCentered('Press <space> to play.', { 1, 1, 1 })
  end
end

function love.keypressed(key, scancode, isrepeat)
  if 'space' == key then
    game.isPaused = not game.isPaused
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
    volatile = (50 >= love.math.random(1, 100))
  }
  table.insert(objects.metroids, metroid)
  world:add(metroid, metroid.x, metroid.y, metroid.w, metroid.h)
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

  local future_x = self.x + self.vx * dt
  local future_y = self.y + self.vy * dt

  local next_x, next_y, cols, len = world:move(self, future_x, future_y, function(item, other)
    -- return values must be "touch", "cross", "slide", "bounce" or nil
    if "ground" == other.type then return "slide"
    elseif "border" == other.type then return "slide"
    elseif "metroid" == other.type then return "touch"
    else return nil end
  end)
  for i, col in ipairs(cols) do
    print("col player:" .. col.other.type .." -> " .. col.type)

    -- bounce of obstacles horizontally
    if ("metroid" == col.other.type and col.normal.x < 0 and self.vx > 0) or (col.normal.x > 0 and self.vx < 0) then
      self.vx = -self.vx
    end

    -- stop jumping
    if ("ground" == col.other.type and col.normal.y < 0 and self.vy > 0) then
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
    print("col metroid:" .. col.other.type .." -> " .. col.type)
    if len > 0 and "ground" == col.other.type and self.volatile then
      table.remove(objects.metroids, i)
      world:remove(self)
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
