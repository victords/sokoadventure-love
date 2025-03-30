Ball = setmetatable({}, MovableObject)
Ball.__index = Ball

function Ball.new(x, y, area, set)
  local self = MovableObject.new(x, y, area .. "/ballAim", 3, 1)
  setmetatable(self, Ball)
  self.set = set
  self.unset_img = Res.img(area .. "/ball")
  return self
end

function Ball:update(_)
  if self.set then self:animate({1, 2, 3, 2}, 12) end
end

function Ball:draw()
  if self.set then
    MovableObject.draw(self)
  else
    self.unset_img:draw(self.x, self.y)
  end
end
