Window = {}
Window.__index = Window

function Window.setSize(width, height, fullscreen, reference_width, reference_height)
  Window.window_width = width
  Window.window_height = height
  reference_width = reference_width or width
  reference_height = reference_height or height
  Window.reference_width = reference_width
  Window.reference_height = reference_height

  if fullscreen then
    local _, _, flags = love.window.getMode()
    local w, h = love.window.getDesktopDimensions(flags.display)
    Window.width = w
    Window.height = h
  else
    Window.width = width
    Window.height = height
  end

  if Window.width ~= reference_width or Window.height ~= reference_height then
    local window_ratio = Window.width / Window.height
    local reference_ratio = reference_width / reference_height
    if window_ratio > reference_ratio then
      Window.scale = Window.height / reference_height
    else
      Window.scale = Window.width / reference_width
    end
    Window.offset_x = math.floor((Window.width - Window.scale * reference_width) / 2)
    Window.offset_y = math.floor((Window.height - Window.scale * reference_height) / 2)
    Window.canvas = love.graphics.newCanvas(reference_width, reference_height)
  else
    Window.scale = 1
    Window.offset_x = 0
    Window.offset_y = 0
    Window.canvas = nil
  end

  love.window.setMode(Window.width, Window.height, { fullscreen = fullscreen })
end

function Window.toggle_fullscreen()
  local currently_fullscreen = love.window.getFullscreen()
  Window.setSize(Window.window_width, Window.window_height, not currently_fullscreen, Window.reference_width, Window.reference_height)
end

function Window.draw_rectangle(x, y, w, h, color, mode)
  color = color or {1, 1, 1}
  mode = mode or "fill"
  love.graphics.setColor(color)
  love.graphics.rectangle(mode, x, y, w, h)
  love.graphics.setColor(1, 1, 1)
end

function Window.draw(draw_code)
  if Window.canvas then
    love.graphics.setCanvas(Window.canvas)
    love.graphics.clear()
  end

  draw_code()

  if Window.canvas then
    love.graphics.setCanvas()
    love.graphics.draw(Window.canvas, Window.offset_x, Window.offset_y, nil, Window.scale, Window.scale)
  end
end
