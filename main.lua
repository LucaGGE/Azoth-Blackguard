--[[
    Azoth! Blackguard game system by Luca 'Grislic' Giovani
    Copyright (C) 2023 Luca Giovani

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

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
    -- first thing first, use OS time to obtain unpredictable random numbers
    math.randomseed(os.time())
    -- game screen and tile settings
    GAME_SCREEN = love.window.setMode(g.window_width, g.window_height, 
    {resizable=true, vsync=0, minwidth=400, minheight=300}
    )

    -- immediately store in util.lua all sprites_groups for entities blueprints
    sprites_groups_manager()

    -- then create and store all blueprints
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