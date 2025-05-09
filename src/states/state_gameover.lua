StateGameOver = BaseState:extend()

-- used to avoid skipping game over screen by mistake
local can_input
-- menu dedicated canvas (gameover only)
local canvas_gameover

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

    -- setting background color to base dark blue or mod color
    love.graphics.setBackgroundColor(
        (mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255
    )

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
    Timer.after(1, function ()
        -- empty previously pressed keys and enable input
        g.keys_pressed = {}
        can_input = true
    end)
    
    g.game_state:refresh()  
end

function StateGameOver:update()
    if not can_input then return end

    -- checking for input to resolve turns
    for i,key in ipairs(g.keys_pressed) do     
        if key == "enter" or key == "return" then
            love.audio.stop(MUSIC["gameover_sting"])
            love.audio.stop(MUSIC["gameover"])
            g.game_state = StateMenu()
            g.game_state:init()
        end
    end
    g.keys_pressed = {}
end

function StateGameOver:refresh()
    canvas_gameover = ui_manager_gameover()

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()
end

function StateGameOver:draw()
    love.graphics.draw(canvas_gameover, 0, 0)
end