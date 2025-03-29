ImageFont = setmetatable({}, Font)
ImageFont.__index = ImageFont

function ImageFont.new(path, characters, char_spacing, img_extension)
  local self = setmetatable({}, ImageFont)
  img_extension = img_extension or "png"
  local full_path = Res.prefix .. Res.font_prefix .. path .. "." .. img_extension
  self.source = love.graphics.newImageFont(full_path, characters, char_spacing)
  self.height = self.source:getHeight()
  return self
end
