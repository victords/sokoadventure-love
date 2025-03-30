Man = setmetatable({}, MovableObject)
Man.__index = Man

function Man.new(x, y)
  local self = MovableObject.new(x, y, "man", 3, 4)
  setmetatable(self, Man)
  self.img_index = 4
  self.indices = {4, 5, 6, 5}
  self.dir = 2
end

function Man:set_dir(dir)
  self.dir = dir
  if dir == 0 then
    self.indices = {1, 2, 3, 2}
  elseif dir == 1 then
    self.indices = {10, 11, 12, 11}
  elseif dir == 2 then
    self.indices = {4, 5, 6, 5}
  else
    self.indices = {7, 8, 9, 8}
  end
  self:reset_animation(self.indices[1])
end

function Man:update()
  self:animate(self.indices, 12)
end
