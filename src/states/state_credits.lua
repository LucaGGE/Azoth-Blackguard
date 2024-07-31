StateCredits = BaseState:extend()

-- credits image
local credits = love.graphics.newImage(mod.path_to_tileset or "graphics/grislycreations.jpg")
local credits_width = credits:getWidth()
local credits_height = credits:getHeight()
local scale = g.window_height / 1300

function StateCredits:manage_input(key)
    table.insert(g.keys_pressed, key)
end

function StateCredits:init()
    if g.game_track then
        love.audio.stop(g.game_track)
    end
    
    g.game_state:refresh()
    love.graphics.setBackgroundColor(0 / 255, 0 / 255, 0 / 255)
end

function StateCredits:update()
    -- this is simply an optimal proportion between the image size and the screen size
    scale = g.window_height / 1300
    -- on any key pressed, empty inputs to avoid acceidents and go to menu
    if g.keys_pressed[1] then
        g.keys_pressed = {}
        g.game_state = StateMenu()
        StateMenu:init()
    end
end

function StateCredits:draw()
    love.graphics.setCanvas()
    -- always keeping the image with its original proportions and in the screen center
    love.graphics.draw(
        credits,
        g.window_width / 2 - (credits_width / 2 * scale), g.window_height / 2 - (credits_height / 2 * scale),
        0, scale, scale
    )
end