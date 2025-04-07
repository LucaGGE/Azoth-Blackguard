local AI_DTABLE = {
    ["aggressive"] = function(owner, npc_comp)
        local other_pawn
        local other_pilot

        other_pawn = target_entity(owner, npc_comp)

        if not other_pawn then
            return false
        end

        other_pilot = other_pawn.comp["npc"] or other_pawn.comp["player"]

        if other_pilot.group ~= npc_comp.group then
            -- reset other_pawn to its initial value
            local target_row = other_pawn.cell["grid_row"]
            local target_col = other_pawn.cell["grid_col"]
            local out_row
            local out_col
            local direction

            if owner.cell["grid_row"] < target_row then
                out_row = 1
            elseif owner.cell["grid_row"] == target_row then
                out_row = 0
            else 
                out_row = -1 
            end
            if owner.cell["grid_col"] < target_col then
                out_col = 1
            elseif owner.cell["grid_col"] == target_col then
                out_col = 0
            else 
                out_col = -1 
            end

            direction = {out_row, out_col}

            owner.comp["movable"]:move_entity(owner, direction)

            return true
        end

    end
}

-- this simple function feeds necessary input in AI_DTABLE,
-- which in turns manages NPC behavior
function ai_behavior(owner, npc_comp)
    -- check nature validity
    if not AI_DTABLE[npc_comp.nature] then
        --print("ERROR: invalid NPC nature: " .. npc_comp.nature)
        return false
    end

    return AI_DTABLE[npc_comp.nature](owner, npc_comp)    
end

function target_entity(owner, npc_comp)
    local search_row = owner.cell["grid_row"] - npc_comp.sight
    local search_col
    local col_condition
    local row_condition
    local targets = {}
    local new_target = false

    -- TO DO TO DO TO DOTO DO TO DO TO DOTO DO TO DO TO DOTO DO TO DO TO DO: need to choose target & ignore ones hidden behind obstacles
    -- searching for enemy entities in a square. This algorithm is temporary and badly designed.
    for i = 0, npc_comp.sight * 2 do
        search_col = owner.cell["grid_col"] - npc_comp.sight
        for j = 0, npc_comp.sight * 2 do
            local target
            -- check if search is happening beyond grid boundaries
            col_condition = search_col > g.grid_x or search_col <= 0
            row_condition = search_row > g.grid_y or search_row <= 0

            -- if search conditions are invalid, skip loop
            if col_condition or row_condition then
                goto continue
            end

            target = g.grid[search_row][search_col].pawn

            -- skip code if found no Entity or self
            if not target or target == owner then
                goto continue
            end

            -- evaluate target only if it is not an obstacle
            if target.comp["npc"] or target.comp["player"] then
                print("Found potential target: " .. target.name)
                table.insert(targets, target)                
            end

            ::continue::
            
            search_col = search_col + 1
        end
        search_row = search_row + 1
    end

    -- skip rest of code if no Entity was found
    if not targets[1] then
        npc_comp.target = false
        return false
    end

    -- try to find old target
    for _, target in ipairs(targets) do
        if target == npc_comp.target then
            print("Found old target: " .. target.name)
            return target
        end
        -- if potential new_target was already established, skip rest of code
        if new_target then
            goto skip
        end
        -- exploit loop to search for potential new target, favor enemies
        for _, group in ipairs(npc_comp.enemies) do
            if group == target.group then
                print("Found Entity from enemy group: " .. target.name)
                new_target = target
            end
        end

        ::skip::
    end
    -- at this point, no old target was found; check if new_target is assigned
    if new_target then
        npc_comp.target = new_target
        print("Selected first Entity from enemy group found")
        return new_target
    end
    -- if it wasn't assigned, return first found target
    npc_comp.target = targets[1]
    print("Selected first target found: " .. targets[1].name)
    return targets[1]
end