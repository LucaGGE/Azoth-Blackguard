-- ROGUE24 by Luca 'Grislic' Giovani, started in 2023.

-- requiring dependencies
require "src.dependencies"

-- initializing main variables
local GAME_SCREEN
GAME_TITLE = "Rogue24 - "..GAME_TITLE
love.window.setTitle(GAME_TITLE)
love.graphics.setDefaultFilter("nearest", "nearest")

-- current state of the game
g.game_state = StateMenu()

function love.keypressed(key)
    -- all inputs with few system-related exceptions are handled inside Game States    
    if key == "f11" then
        fullscreen = not fullscreen
        love.window.setFullscreen(fullscreen)
        g.window_width, g.window_height = pixel_adjust(love.graphics.getDimensions())
    elseif key == "delete" then
        if g.error_messages and not g.game_state:is(StateFatalError) then
            if love.keyboard.isDown("lctrl") then
                -- with lctrl down, clean all error messages
                g.error_messages = {}
            else
                table.remove(g.error_messages, 1)
            end
        end
    else
        g.game_state:manage_input(key)
    end
end

function love.load()
    -- game screen and tile settings
    GAME_SCREEN = love.window.setMode(g.window_width, g.window_height, 
    {resizable=true, vsync=0, minwidth=400, minheight=300}
    )

    -- immediately create and store all blueprints
    local blueprints = blueprints_manager()

    -- if something went wrong, immediately go in StateFatalError()
    if not blueprints then
        g.game_state = StateFatalError()
    end

    g.game_state:init()
end

function love.update(dt)
    Timer.update(dt)
    g.game_state:update()
end

function love.draw()
    g.game_state:draw()

    -- errors will always be printed on screen, to aid modders
    love.graphics.setFont(FONTS["default"])
    for i, error_msg in ipairs(g.error_messages) do
        love.graphics.print(error_msg, 0, (i - 1) * FONT_SIZE_DEFAULT)
    end
end