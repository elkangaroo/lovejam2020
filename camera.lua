local camera = {}
camera.x = 0
camera.y = 0
camera.scaleX = 1
camera.scaleY = 1
camera.rotation = 0
camera.layers = {}

function camera:set()
  love.graphics.push()
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
  love.graphics.translate(-self.x, -self.y)
end

function camera:unset()
  love.graphics.pop()
end

function camera:move(dx, dy)
  self.x = self.x + (dx or 0)
  self.y = self.y + (dy or 0)
end

function camera:rotate(dr)
  self.rotation = self.rotation + dr
end

function camera:scale(sx, sy)
  sx = sx or 1
  self.scaleX = self.scaleX * sx
  self.scaleY = self.scaleY * (sy or sx)
end

function camera:setPosition(x, y)
  self.x = x or self.x
  self.y = y or self.y
end

function camera:setScale(sx, sy)
  self.scaleX = sx or self.scaleX
  self.scaleY = sy or self.scaleY
end

function camera:newLayer(scale, drawFunc)
  table.insert(self.layers, { scale = scale, draw = drawFunc })
  table.sort(self.layers, function(a, b) return a.scale < b.scale end)
end

function camera:draw()
  local bx, by = self.x, self.y

  for _, layer in ipairs(self.layers) do
    self.x = bx * layer.scale
    self.y = by * layer.scale
    camera:set()
    layer.draw()
    camera:unset()
  end

  self.x, self.y = bx, by
end

return camera
