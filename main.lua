require("src.game")

function love.load()
  Game.load()
  love.window.setFullscreen(Game.full_screen, "desktop")
end

function love.update(dt)
  Game.update()
end

function love.draw()
  Game.draw()
end
