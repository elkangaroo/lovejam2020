local bump = require "vendor.bump"
local camera = require "camera"
local game = {
  isPaused = true,
  timer = 0,
}
local world
local objects = {}

local CAMERA_SPEED = 50
local ACC_GRAVITY = 500 -- pixels per second^2
local LEVEL_WIDTH = love.graphics.getWidth()
local LEVEL_HEIGHT = love.graphics.getHeight()

function love.load(arg)
  world = bump.newWorld(64) -- cell size = 64

  -- ground
  objects.ground = {x = 0, y = LEVEL_HEIGHT - 48, w = LEVEL_WIDTH * 100, h = 48}
  world:add(objects.ground, objects.ground.x, objects.ground.y, objects.ground.w, objects.ground.h)
  camera:newLayer(1, function()
    love.graphics.setColor(0.28, 0.63, 0.05)
    love.graphics.rectangle("fill", objects.ground.x, objects.ground.y, objects.ground.w, objects.ground.h)
  end)

  -- player
  objects.player = {x = 16, y = LEVEL_HEIGHT - 2*48, w = 96, h = 48, vx = 0, vy = 0, acc_run = 200, acc_jump = 400}
  world:add(objects.player, objects.player.x, objects.player.y, objects.player.w, objects.player.h)
  camera:newLayer(1, function()
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("fill", objects.player.x, objects.player.y, objects.player.w, objects.player.h)
  end)

  -- metroids
  objects.metroids = {}
  addMetroid()
  camera:newLayer(1, function()
    for i, item in ipairs(objects.metroids) do
      love.graphics.setColor(0.20, 0.30, 0.40)
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

  updatePlayer(objects.player, dt)
  for i, metroid in ipairs(objects.metroids) do
    updateMetroid(metroid, dt, i)
  end
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  camera:draw()

  love.graphics.setColor(0.3, 0.9, 1)
  love.graphics.print(string.format('FPS: %s Time: %s', love.timer.getFPS(), (math.floor(game.timer * 10) * 0.1)), 2, 2)

  if game.isPaused then
    drawTextCentered('Press <space> to play.', { 1, 1, 1 })
  end
end

function love.keypressed(key, scancode, isrepeat)
  if 'space' == key then
    game.isPaused = false
  end
end

function love.keyreleased(key, scancode)

end

function addMetroid()
  local metroid = {
    x = love.math.random(camera.x, camera.x + LEVEL_WIDTH),
    y = love.math.random(camera.y, camera.y + LEVEL_HEIGHT / 2),
    w = 32,
    h = 32,
    vx = 0,
    vy = 0,
    acc = love.math.random(200, 250),
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

  local next_x, next_y, cols, len = world:move(self, future_x, future_y)
  for i = 1, len do
    local col = cols[i]
    -- bounce of obstacles horizontally
    if (col.normal.x < 0 and self.vx > 0) or (col.normal.x > 0 and self.vx < 0) then
      self.vx = -self.vx
    end

    -- stop jumping
    if (col.normal.y < 0 and self.vy > 0) then
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
  if len > 0 and self.volatile then
    table.remove(objects.metroids, i)
    world:remove(self)
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
