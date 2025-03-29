Sprite = {}
Sprite.__index = Sprite

function Sprite.new(x, y, img_path, cols, rows)
  cols = cols or 1
  rows = rows or 1
  local self = setmetatable({}, Sprite)
  self.x = x
  self.y = y
  self.img_path = img_path
  self.cols = cols
  self.rows = rows

  self.img = love.graphics.newImage(img_path)
  self.img_index = 1
  self.index_index = 1
  self.anim_timer = 0
  self.animate_once_control = 0

  local img_width = self.img:getWidth()
  local img_height = self.img:getHeight()
  self.col_width = math.floor(img_width / cols)
  self.row_height = math.floor(img_height / rows)
  local total_quads = cols * rows
  self.quads = {}
  for i = 1, total_quads do
    self.quads[i] = love.graphics.newQuad(((i - 1) % cols) * self.col_width, math.floor((i - 1) / cols) * self.row_height, self.col_width, self.row_height, img_width, img_height)
  end

  return self
end

function Sprite:animate(indices, interval)
  if self.animate_once_control ~= 0 then self.animate_once_control = 0 end

  self.anim_timer = self.anim_timer + 1
  if self.anim_timer >= interval then
    self.index_index = self.index_index % #indices + 1
    self.img_index = indices[self.index_index]
    self.anim_timer = 0
  end
end

function Sprite:animate_once(indices, interval, callback)
  if self.animate_once_control == 2 then return end

  if self.animate_once_control == 0 then
    self.anim_timer = 0
    self.img_index = indices[1]
    self.index_index = 1
    self.animate_once_control = 1
  end

  self.anim_timer = self.anim_timer + 1
  if self.anim_timer < interval then return end

  if self.index_index == #indices then
    self.animate_once_control = 2
    callback()
  else
    self.index_index = self.index_index + 1
    self.img_index = indices[self.index_index]
    self.anim_timer = 0
  end
end

function Sprite:reset_animation(img_index)
  self.img_index = img_index
  self.index_index = 1
  self.anim_timer = 0
  self.animate_once_control = 0
end

function Sprite:draw(scale_x, scale_y, color, angle, flip)
  scale_x = scale_x or 1
  scale_y = scale_y or 1
  angle = angle and (angle * math.pi / 180)
  local origin_x = 0.5 * self.col_width
  local origin_y = 0.5 * self.row_height
  local scale_x_factor = flip == "horiz" and -1 or 1
  local scale_y_factor = flip == "vert" and -1 or 1
  if color then love.graphics.setColor(color) end
  love.graphics.draw(self.img, self.quads[self.img_index], self.x + scale_x * origin_x, self.y + scale_y * origin_y, angle, scale_x_factor * scale_x, scale_y_factor * scale_y, origin_x, origin_y)
  if color then love.graphics.setColor(1, 1, 1) end
end
