StatePlay = BaseState:extend()

-- this variable stores the current turn
local current_turn = 1

--[[
    Here's where we accumulate key inputs for players, to contain their number.
    This is done to make the game feel more responsive.
    NOTE: we cannot accumulate input if we are in multiplayer!
]]
function StatePlay:manage_input(key)
    -- managing input for multiple players
    if #g.party_group > 1 then
        if #g.keys_pressed == 0 and next(g.tweening) == nil then
            table.insert(g.keys_pressed, key)
        end
    else
        if #g.keys_pressed <= 1 then
            table.insert(g.keys_pressed, key)
        else
            print("Tweening, ignoring input")
        end
    end
end

-- NOTE: StatePlay:init() is here to take level-related arguments and spawn them
function StatePlay:init(map, generate_players)
    -- stopping previous soundtrack
    if g.game_track then
        love.audio.stop(g.game_track)
    end
    -- starting soundtrack
    g.game_track = MUSIC["swamp"]
    g.game_track:setLooping(true)
    love.audio.play(g.game_track)

    -- feeding 'true' the first level, to regen players
    local current_map = map_reader(map, generate_players)

    if current_map then
        -- setting BKG color
        love.graphics.setBackgroundColor(
            (mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255
        )

        -- first drawing pass on g.cnv_static, to avoid re-drawings statics
        love.graphics.setCanvas(g.cnv_static)

        -- using g.cnv_static as a base for final, updated drawing with dynamics
        for i, v in ipairs(g.grid) do
            for i2, v2 in ipairs(v) do
                if g.grid[i][i2].tile ~= nil then
                    love.graphics.draw(
                        TILESET, g.grid[i][i2].tile, g.grid[i][i2].x, g.grid[i][i2].y
                    )
                end
            end
        end

        -- resetting to default canvas
        love.graphics.setCanvas()

        -- setting camera and launching player inventory
        camera_setting()
        panel_update(g.party_group[current_turn])
    else
        g.game_state:exit()
        g.game_state = StateFatalError()
        g.game_state:init()
    end
    
    g.game_state:refresh()
    
end

function StatePlay:update()
    local valid_action 

    -- checking for input to resolve turns
    if g.keys_pressed[1] and next(g.tweening) == nil then
        local player = g.party_group[current_turn]
        
        -- sending input to current player input_manager (if alive)
        if player then
            for i2,key in ipairs(g.keys_pressed) do
                valid_action = player.comp["player"]:manage_input(player, key)
                -- removing input that was taken care of
                table.remove(g.keys_pressed, i2)
                -- if action isn't valid, return false and wait for valid return
                if not valid_action then return false end
            end
        end

        -- at this point, a valid action was taken.
        -- If not, player died (g.party_group[current_turn] == nil)
        if valid_action or g.party_group[current_turn] then
            -- a successful action quits the action mode
            player.comp["player"].action_state = nil
            -- a successful action closes inventory
            g.panel_on = false 
            current_turn = current_turn + 1
        end

        -- NOTE: be careful with tweening. Check State before activating.
        if not g.game_state:is(StatePlay) then
            goto continue_statechange
        end

        -- if the current_turn (now + 1) exceeds the n of players, it's NPCs turn
        if not g.party_group[current_turn] then
            -- reset turn system to 1
            current_turn = 1
            -- block player from doing anything while g.camera and NPCs act
            g.tweening["turn"] = true
            -- if g.party_group[1] is false, all players died/we are changing level
            if g.party_group[current_turn] then
                -- reset current_turn number, move NPCs and apply their effects
                turns_manager(g.party_group[current_turn])
                panel_update(g.party_group[current_turn])
            elseif g.game_state:is(StatePlay) then
                -- if we didn't simply pass through an exit, it's a Game Over!
                g.game_state = StateGameOver()
                g.game_state:init()
            end
        else
            g.tweening["turn"] = true
            
            -- Move NPCs and apply their effects
            -- Player/NPCs is established by second arg, true/false!
            turns_manager(g.party_group[current_turn])
        end
        -- pre-tween refresh
        g.game_state:refresh()
        ::continue_statechange::
    end

    -- flashing last console event, if any new events received in console_event
    if g.new_event then
        g.new_event = false
        g.tweening["event"] = true
        
        local final_color = g.console["rgb1"]
        local flash_color = {1, 1, 1, 1}

        -- flashing last event in white, if just printed
        g.console["rgb1"] = flash_color
        g.cnv_ui = ui_manager_play()

        -- flash white last console message
        Timer.tween(TWEENING_TIME, {}):finish(function ()
            g.console["rgb1"] = final_color
            g.cnv_ui = ui_manager_play()
            -- check if a cutscene is being played
            g.tweening["event"] = nil
        end)
    end
end

function StatePlay:refresh()
    -- setting canvas to g.cnv_dynamic, clearing it and drawing cnv_static as base
    love.graphics.setCanvas(g.cnv_dynamic)
    -- erase canvas with BKG color and draw g.cnv_static as a base to draw upon
    love.graphics.clear(
        (mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255
    )
    love.graphics.draw(g.cnv_static, 0, 0)

    -- removing dead players from g.party_group
    for i, player in ipairs(g.party_group) do
        if player.alive == false then
            player.cell["cell"].pawn = nil
            table.remove(g.party_group, i)
        end
    end

    -- removing dead NPCs from g.npcs_group
    for i, npc in ipairs(g.npcs_group) do
        if npc.alive == false then
            npc.cell["cell"].pawn = nil
            table.remove(g.npcs_group, i)
        end
    end
    
    -- removing all visible dead/invalid entities (also contains NPCs and players)
    for i, entity in ipairs(g.render_group) do
        -- entities can have their properties drastically changed,
        -- that's why this check is needed each refresh() cycle
        if not tile_to_quad(entity.tile) then
            error_handler(
                entity.id.." has invalid tile index and cannot be drawn, removed."
            )
            table.remove(g.render_group, i)
            entity.alive = false
        end

        -- check if Entity is not dead, but was moved to inventory
        if entity.alive == "inventory" then
            entity_kill(entity, i, g.render_group)
            entity.alive = true
        end

        if not entity.alive then
            entity_kill(entity, i, g.render_group)
        end
    end

    -- removing all invisible dead/invalid entities (also contains NPCs and players)
    for i, entity in ipairs(g.hidden_group) do
        -- entities can have their properties drastically changed,
        -- that's why this check is needed each refresh() cycle
        if not tile_to_quad(entity.tile) then
            error_handler(
                entity.id.." has invalid tile index and cannot be drawn, removed."
            )
            table.remove(g.hidden_group, i)
            entity.alive = false
        end

        -- check if Entity is not dead, but was moved to inventory
        if entity.alive == "inventory" then
            entity_kill(entity, i, g.render_group)
            entity.alive = true
        end

        if not entity.alive then
            entity_kill(entity, i, g.hidden_group)
        end
    end

    -- drawing in a loop all the elements to be drawn on screen
    for i, entity in ipairs(g.render_group) do
        love.graphics.draw(
            TILESET, tile_to_quad(entity.tile), entity.cell["cell"].x, entity.cell["cell"].y
        )
    end

    g.cnv_ui = ui_manager_play()
    if g.party_group[current_turn] then
        panel_update(g.party_group[current_turn])
    end
end

function StatePlay:draw()
    -- if inventory is open and there's a player, draw inventory and return
    if g.panel_on and g.camera["entity"] then
        love.graphics.draw(g.cnv_inv, 0, 0)
        -- drawing UI dedicated canvas on top of everything, always locked on screen
        love.graphics.draw(g.cnv_ui, 0, 0)
        return true            
    end

    -- draw g.cnv_dynamic on the screen, with g.camera offset.
    if g.camera["entity"] then
        -- screen is drawn on g.cnv_dynamic perfectly centered to player
        love.graphics.draw(g.cnv_dynamic,
        (g.w_width / 2) - (g.camera["x"] * SIZE_MULT) - HALF_TILE,
        (g.w_height / 2) - (g.camera["y"] * SIZE_MULT) - HALF_TILE,
        0,
        SIZE_MULT,
        SIZE_MULT
        )
    else
        -- if for any reason there's no player,
        -- g.camera points 0,0 with its left upper corner
        love.graphics.draw(g.cnv_dynamic, 0, 0, 0, SIZE_MULT, SIZE_MULT)
    end

    -- drawing UI dedicated canvas on top of everything, always locked on screen
    love.graphics.draw(g.cnv_ui, 0, 0)
end

function StatePlay:exit()
    g.npcs_group = {}
    g.render_group = {}
end