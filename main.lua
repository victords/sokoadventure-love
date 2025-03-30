require("src.game")

function love.load()
  Game.load()
end

function love.update(dt)
  Game.update()
end

function love.draw()
  Game.draw()
end
