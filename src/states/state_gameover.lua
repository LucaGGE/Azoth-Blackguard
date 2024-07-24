StateGameOver = BaseState:extend()

-- used to avoid skipping game over screen by error
local can_input

-- used to print all the death messages on screen
local players_count

function StateGameOver:manage_input(key)
    table.insert(g.keys_pressed, key)
end

function StateGameOver:init()
    -- block player from instantly skipping gameover menu
    can_input = false
    
    -- stopping current soundtrack
    if g.game_track then
        love.audio.stop(g.game_track)
    end

    -- setting background color with calming pink for fatal errors
    love.graphics.setBackgroundColor(0 / 255, 0 / 255, 0 / 255)

    -- play the gameover sting
    love.audio.play(MUSIC["gameover_sting"])
    -- wait for the sting to finish and fade in with music
    Timer.after(20, function () 
        if g.game_state:is(StateGameOver) then
            g.game_track = MUSIC["gameover"]
            g.game_track:setLooping(true)
            love.audio.play(g.game_track)
        end
    end)
    -- unlock input for player after few seconds
    Timer.after(2, function ()
        -- empty previously pressed keys and enable input
        g.keys_pressed = {}
        can_input = true
    end)    
end

function StateGameOver:update()
    -- checking for input to resolve turns
    if g.keys_pressed[1] and can_input then
        for i,key in ipairs(g.keys_pressed) do     
            print(key)
            if key == "enter" or key == "return" then
                love.audio.stop(MUSIC["gameover_sting"])
                love.audio.stop(MUSIC["gameover"])
                g.game_state = StateMenu()
                g.game_state:init()
            end
        end
        g.keys_pressed = {}
    end
end

function StateGameOver:draw()
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.setFont(FONTS["title"])
    love.graphics.printf("Game Over", 0, g.window_height / 4 - FONT_SIZE_TITLE, g.window_width, 'center')

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(FONTS["subtitle"])
    love.graphics.printf("These souls have left us forever:", 0, g.window_height / 4 + (FONT_SIZE_SUBTITLE), g.window_width, 'center')

    -- Printing all deceased players and info about their death
    for i, death in ipairs(g.cemetery) do 
        love.graphics.printf(death["player"]..", killed by "..death["killer"].." for "..death["loot"].." gold,\n"..
        "has found a final resting place in "..death["place"]..".",
        0, g.window_height / 3.5 + (FONT_SIZE_SUBTITLE * (i * 3)), g.window_width, 'center')
    end
end