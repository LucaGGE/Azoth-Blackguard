StatePlay = BaseState:extend()

local SIZE_MULTIPLIER = mod.IMAGE_SIZE_MULTIPLIER or 2 -- used to scale final canvas
local HALF_TILE = (mod.TILE_SIZE or 20) / 2 -- used when centering the screen on player

-- this variable stores the current turn
local current_turn = 1

--[[
    Here's where we accumulate key inputs for Entities, containing their number.
    This is done to make the game feel more responsive.
    NOTE: we cannot accumulate input if we are in multiplayer!
]]--
function StatePlay:manage_input(key)
    -- managing input for multiple players
    if #g.players_party > 1 then
        if #keys_pressed == 0 and not g.is_tweening then
            table.insert(keys_pressed, key)
        end
    else
        if #keys_pressed <= 1 then
            table.insert(keys_pressed, key)
        else
            print("Tweening, ignoring input")
        end
    end
end

-- NOTE: StatePlay:init() is here to take level-related arguments and spawn them
function StatePlay:init(map, regen_players)
    -- stopping previous soundtrack
    if g.game_track then
        love.audio.stop(g.game_track)
    end
    -- startin soundtrack
    g.game_track = MUSIC['swamp']
    g.game_track:setLooping(true)
    love.audio.play(g.game_track)

    -- feeding "true" the first level, to regen players
    local current_map = map_reader(map, regen_players)

    if current_map then
        -- setting BKG color
        love.graphics.setBackgroundColor((mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255)

        -- setting the state's font
        love.graphics.setFont(FONTS["default"])

        -- preliminary drawing pass on g.canvas_base , to avoid re-drawing statics each time 
        love.graphics.setCanvas(g.canvas_base )

        -- using g.canvas_base  with static tiles to create a base for final, updated drawing
        for i, v in ipairs(g.grid) do
            for i2, v2 in ipairs(v) do
                if g.grid[i][i2].tile ~= nil then
                    love.graphics.draw(g.TILESET, g.grid[i][i2].tile, g.grid[i][i2].x, g.grid[i][i2].y)
                end
            end
        end

        -- resetting to Love2D's default canvas
        love.graphics.setCanvas()

        camera_setting()
    else
        g.game_state:exit()
        g.game_state = StateFatalError()
        g.game_state:init()
    end
end

function StatePlay:update()
    -- checking for input to resolve turns
    if keys_pressed[1] and not g.is_tweening then
        -- getting rid of useless references to dead players
        for i,v in ipairs(g.players_party) do
            if v["entity"].alive == false then
                table.remove(g.players_party, i)
            end
        end

        local current_player = g.players_party[current_turn]
        local valid_action
        
        -- sending input to current player input_manager (if alive)
        if current_player then
            for i2,key in ipairs(keys_pressed) do
                valid_action = current_player["player_component"]:input_management(current_player["entity"], key)
                -- removing input that was taken care of
                table.remove(keys_pressed, i2)
            end
        end

        -- checking if a valid action was taken. If not, turn is not over OR player died
        if valid_action or not g.players_party[current_turn] then
            current_turn = current_turn + 1
        end

        -- NOTE: be careful with tweening. Check State before activating.
        if not g.game_state:is(StatePlay) then
            goto continue_statchange
        end

        -- If the current_turn (now + 1) exceeds the n of players, it's NPCs turn
        if not g.players_party[current_turn] then
            -- reset turn system to 1
            current_turn = 1
            -- block player from doing anything while g.camera and NPCs act
            g.is_tweening = true
            -- If g.players_party[1] is not true, all players died/we are changing level
            if g.players_party[current_turn] then
                -- reset current_turn number and move NPCs
                turns_manager(g.players_party[current_turn], true)
            elseif g.game_state:is(StatePlay) then
                -- triggering Game Over, but only if we didn't simply pass through an exit!
                g.game_state = StateGameOver()
                g.game_state:init()
            end
        else
            g.is_tweening = true
            turns_manager(g.players_party[current_turn], false)
        end
        ::continue_statchange::
    end
end

function StatePlay:draw()
    -- setting canvas to g.canvas_final, to give effects and offset before
    love.graphics.setCanvas(g.canvas_final)
    -- erase canvas with BKG color and draw g.canvas_base  as a base to draw upon
    love.graphics.clear((mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255)
    love.graphics.draw(g.canvas_base , 0, 0)
    
    -- drawing in a loop all the elements to be drawn on screen, removing dead ones
    for i, entity in ipairs(g.render_group) do
        if entity.alive then
            if tile_to_quad(entity.tile) then
                love.graphics.draw(g.TILESET, tile_to_quad(entity.tile), entity.cell["cell"].x, entity.cell["cell"].y)
            else
                error_handler(entity.id.." has invalid tile index and cannot be drawn. Removed from render_group")
                table.remove(g.render_group, i)
            end
        else
            table.remove(g.render_group, i)
        end
    end

    -- Reset default canvas and draw g.canvas_final on the screen, with g.camera offset.
    love.graphics.setCanvas()
    if g.camera["entity"] then
        -- screen is drawn on g.canvas_final with player perfectly at the center of it
        love.graphics.draw(g.canvas_final,
        (g.window_width / 2) - (g.camera["x"] * SIZE_MULTIPLIER) - HALF_TILE,
        (g.window_height / 2) - (g.camera["y"] * SIZE_MULTIPLIER) - HALF_TILE,
        0,
        SIZE_MULTIPLIER,
        SIZE_MULTIPLIER
        )
    else
        -- if for any reason there's no player, g.camera points 0,0 with its left upper corner
        love.graphics.draw(g.canvas_final, 0, 0, 0, SIZE_MULTIPLIER, SIZE_MULTIPLIER)
    end

    -- drawing UI on top of everything for the current player    
    love.graphics.setFont(FONTS["subtitle"])

    -- making the UI semi-transparent
    love.graphics.setColor(0.78, 0.96, 0.94, 1)    

    -- TO IMPROVE: THERE IS A LOT OF CALCULATIONS FOR EACH FRAME HERE. HANDLE THIS DATA WITH FUNCS LIKE RESIZE_SCREEN AND DRAW STUFF WITH AS LITTLE CALCS AS POSSIBLE -----------
    -- for dynamic values, strings should be updated with an event called when stats change 

    love.graphics.print(
        g.camera["entity"].name,
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 4)
    )
    love.graphics.print(
        "Life "..g.camera["entity"].features["stats"].stats["hp"],
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 3)
    )
    love.graphics.print(
        "Gold "..g.camera["entity"].features["stats"].stats["gold"], -- ERROR: this is not forced and will therefore crash game if not explicitly input in entities.csv. UI system should be modular and adapt to dynamic stats!  
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 2)
    )

    -- restoring default RGBA, since this function influences ALL graphics
    love.graphics.setColor(1, 1, 1, 1)
end

function StatePlay:exit()
    g.npcs_group = {}
    g.render_group = {}
end