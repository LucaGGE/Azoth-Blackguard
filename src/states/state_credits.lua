StateCredits = BaseState:extend()

-- credits image
local credits_image = love.graphics.newImage(mod.path_to_tileset or "graphics/grislycreations.jpg")

-- menu dedicated canvas (credits only)
local canvas_credits

function StateCredits:manage_input(key)
    table.insert(g.keys_pressed, key)
end

function StateCredits:init()
    if g.game_track then
        love.audio.stop(g.game_track)
    end
    
    love.graphics.setBackgroundColor(0 / 255, 0 / 255, 0 / 255)
    g.game_state:refresh()
end

function StateCredits:update()
    -- on any key pressed, empty inputs to avoid acceidents and go to menu
    if g.keys_pressed[1] then
        g.keys_pressed = {}
        g.game_state = StateMenu()
        StateMenu:init()
    end
end

function StateCredits:refresh()
    canvas_credits = ui_manager_credits(credits_image)

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()
end

function StateCredits:draw()
    love.graphics.draw(canvas_credits, 0, 0)
end