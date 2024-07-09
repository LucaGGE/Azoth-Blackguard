StateFatalError = BaseState:extend()

function StateFatalError:init()
    if g.game_track then
        love.audio.stop(g.game_track)
    end
    love.graphics.setFont(FONTS["default"])
    -- setting background color with calming pink for fatal errors
    love.graphics.setBackgroundColor(255 / 255, 145 / 255, 175 / 255)
    -- warning players that a fatal error has occurred; not using error_handler to have this as the first error message
    table.insert(g.error_messages, 1, "If you are seeing this, a fatal error has occurred. See below for more information.")
end

function StateFatalError:update()
    -- setting background color with calming pink for fatal errors
    love.graphics.setBackgroundColor(255 / 255, 145 / 255, 175 / 255)
end