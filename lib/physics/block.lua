Block = {}
Block.__index = Block

function Block.new(x, y, w, h, passable)
  local self = setmetatable({}, Block)
  self.x = x
  self.y = y
  self.w = w
  self.h = h
  self.passable = passable or false
  return self
end

function Block:bounds()
  return Rectangle.new(self.x, self.y, self.w, self.h)
end
