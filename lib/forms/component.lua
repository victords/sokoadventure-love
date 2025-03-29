Component = {}
Component.__index = Component

function Component.new(x, y, w, h, options)
  local self = setmetatable({}, Component)
  self.anchor, self.x, self.y = Utils.check_anchor(options.anchor, x, y, w, h)
  self.anchor_offset_x = x
  self.anchor_offset_y = y
  self.w = w
  self.h = h
  self.font = options.font
  self.text = options.text
  self.text_color = options.text_color or {0, 0, 0}
  self.disabled_text_color = options.disabled_text_color or {0.5, 0.5, 0.5}
  self.enabled = true
  self.visible = true
  return self
end

function Component:set_position(x, y)
  self.x = x
  self.y = y
end

function Component:set_enabled(value)
  self.enabled = value
end

function Component:update() end
