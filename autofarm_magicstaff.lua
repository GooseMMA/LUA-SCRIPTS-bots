-- =========================================================
-- SCRIPT NAME:
-- MIRAI SOLO FARMER · MIXED PLACE + BREAK · CLEAR BEFORE COLLECT
--
-- MAIN RULE:
-- BEFORE ANY RESOURCE PICKUP, the bot first makes sure that all 5 farm
-- coordinates are empty / fg == 0. Only after that it runs the pickup route.
--
-- WHAT THIS SCRIPT DOES:
-- 1) The bot automatically saves the script start coordinate as HOME.
-- 2) RESTOCK is calculated automatically as:
--      RESTOCK_X = HOME_X - 3
--      RESTOCK_Y = HOME_Y
-- 3) The bot farms 5 coordinates around HOME:
--      HOME_X - 1, HOME_Y + 1
--      HOME_X - 1, HOME_Y + 2
--      HOME_X,     HOME_Y + 2
--      HOME_X + 1, HOME_Y + 2
--      HOME_X + 1, HOME_Y + 1
-- 4) The counter is based on SUCCESSFULLY BROKEN blocks, not placed blocks.
-- 5) Every TARGET_BROKEN_COUNT broken blocks:
--      clear all 5 target coordinates first
--      collect loot/resources
--      restock blocks at HOME_X - 3, HOME_Y
--      return HOME
-- 6) If there is no place/break work for too long:
--      clear all 5 target coordinates first
--      collect loot/resources
--      restock blocks
--      return HOME
--
-- MODE:
-- Mixed mode: if target has a block -> break it; if target is empty -> place and break it.
--
-- REJOIN / WORLD LEAVE BEHAVIOR:
-- Current MIRAI API has no real auto-join function.
-- If the bot leaves the world, the script pauses.
-- When world data appears again, the bot waits AFK for 2 seconds,
-- goes to the last saved position, returns HOME, clears target blocks,
-- collects loot/resources, then continues.
--
-- SPEED NOTE:
-- Speed depends on ping, server delay, and tile update speed.
-- If the bot misses blocks, increase BREAK_DELAY or MOVE/COLLECT delays.
-- =========================================================

-- =========================
-- CONFIG
-- =========================

local PLACE_ITEM_ID = 66
-- Change this to the item ID the bot must place.

local TARGET_BROKEN_COUNT = 100
-- Every 100 successfully broken blocks, the bot clears targets, collects, and restocks.

local RESTOCK_OFFSET_X = -3
local RESTOCK_OFFSET_Y = 0

local EMPTY_ID = 0
local PLACE_LAYER = "fg"
local BREAK_LAYER = "fg"

local WAIT_WORLD_DELAY = 1000
local REJOIN_AFK_WAIT_MS = 2000

local MOVE_WAIT_MS = 40
local RESTOCK_WAIT_MS = 1000

local PLACE_DELAY_MS = 20
local NO_WORK_WAIT_MS = 25

local IDLE_RESTOCK_AFTER_MS = 15000
-- If the bot cannot place or break anything for this long, it will clear targets,
-- collect loot, and restock.

local IDLE_RESTOCK_LOG_EVERY_MS = 5000

local BREAK_DELAY_MIN = 190
local BREAK_DELAY_MAX = 210
local MAX_HITS_PER_TARGET = 40
local MAX_CLEAR_PASSES = 8

local COLLECT_ROUTE_PASSES = 2
local COLLECT_MOVE_WAIT_MS = 90
local COLLECT_EXTRA_HOME_SWEEP = true

math.randomseed(os.time())

-- =========================
-- STATE
-- =========================

local HOME_X = nil
local HOME_Y = nil
local RESTOCK_X = nil
local RESTOCK_Y = nil

local broken_count = 0

local last_work_time_ms = os.time() * 1000
local last_idle_log_time_ms = 0
local is_resource_cycle_running = false

local was_out_of_world = false
local needs_rejoin_recovery = false
local last_known_x = nil
local last_known_y = nil

-- =========================
-- TARGET PATTERN
-- =========================

local OFFSETS = {
    {-1, 1},
    {-1, 2},
    { 0, 2},
    { 1, 2},
    { 1, 1}
}

-- =========================
-- FORWARD DECLARATIONS
-- =========================

local collect_loot
local restock
local clear_all_targets
local resource_cycle
local finish_broken_cycle_if_needed
local idle_restock_if_needed

-- =========================
-- BASIC UTILS
-- =========================

local function now_ms()
    return os.time() * 1000
end

local function rand(a, b)
    return math.random(a, b)
end

local function rsleep(a, b)
    sleep(rand(a, b))
end

local function mark_work(reason)
    last_work_time_ms = now_ms()

    if reason then
        log("[WORK] " .. tostring(reason))
    end
end

local function get_world()
    local ok, world

    if bot.get_world then
        ok, world = pcall(function()
            return bot.get_world()
        end)

        if ok and world then
            return world
        end
    end

    if bot.world then
        ok, world = pcall(function()
            return bot.world()
        end)

        if ok and world then
            return world
        end
    end

    return nil
end

local function wait_world()
    while true do
        local world = get_world()

        if world and world.width and world.height then
            if was_out_of_world then
                log("[REJOIN] World data returned. AFK wait before recovery.")
                sleep(REJOIN_AFK_WAIT_MS)
                needs_rejoin_recovery = true
                was_out_of_world = false
            end

            return world
        end

        was_out_of_world = true
        log("[PAUSE] Bot is not in world. Waiting...")
        sleep(WAIT_WORLD_DELAY)
    end
end

local function get_pos()
    local ok, pos = pcall(function()
        return bot.pos()
    end)

    if ok then
        return pos
    end

    return nil
end

local function get_bot_tile()
    local pos = get_pos()

    if not pos then
        return 0, 0
    end

    local x = pos.tile_x or pos.x or 0
    local y = pos.tile_y or pos.y or 0

    last_known_x = x
    last_known_y = y

    return x, y
end

local function capture_home_once()
    if HOME_X ~= nil and HOME_Y ~= nil then
        return
    end

    wait_world()

    local x, y = get_bot_tile()
    HOME_X = x
    HOME_Y = y

    RESTOCK_X = HOME_X + RESTOCK_OFFSET_X
    RESTOCK_Y = HOME_Y + RESTOCK_OFFSET_Y

    log("[HOME AUTO] HOME = " .. tostring(HOME_X) .. "," .. tostring(HOME_Y))
    log("[RESTOCK AUTO] RESTOCK = " .. tostring(RESTOCK_X) .. "," .. tostring(RESTOCK_Y))
end

local function in_bounds(world, x, y)
    if not world then return false end
    if not world.width or not world.height then return false end
    if x < 0 then return false end
    if y < 0 then return false end
    if x >= world.width then return false end
    if y >= world.height then return false end
    return true
end

local function path_to(x, y)
    wait_world()

    local ok, result = pcall(function()
        return bot.find_path(x, y)
    end)

    if ok and result and result.ok then
        if MOVE_WAIT_MS > 0 then
            sleep(MOVE_WAIT_MS)
        end

        get_bot_tile()
        return true
    end

    log("[PATH FAIL] " .. tostring(x) .. "," .. tostring(y))
    return false
end

local function return_home()
    capture_home_once()
    wait_world()

    local bx, by = get_bot_tile()

    if bx == HOME_X and by == HOME_Y then
        return true
    end

    return path_to(HOME_X, HOME_Y)
end

local function get_tile_fg(x, y)
    wait_world()

    local ok, tile = pcall(function()
        return bot.tile(x, y)
    end)

    if ok and tile then
        return tile.fg
    end

    return nil
end

local function is_empty(x, y)
    local fg = get_tile_fg(x, y)
    return fg == nil or fg == EMPTY_ID
end

local function get_inventory_amount(item_id)
    wait_world()

    local ok, inv = pcall(function()
        return bot.inventory()
    end)

    if not ok or not inv then
        return 0
    end

    for _, item in ipairs(inv) do
        local id = item.id or item.item_id
        local amount = item.amount or 0

        if id == item_id then
            return amount
        end
    end

    return 0
end

local function get_pattern_positions()
    capture_home_once()

    local positions = {}

    for i, off in ipairs(OFFSETS) do
        positions[#positions + 1] = {
            x = HOME_X + off[1],
            y = HOME_Y + off[2],
            index = i
        }
    end

    return positions
end

local function add_broken_count(x, y)
    broken_count = broken_count + 1
    mark_work("broken block")

    log("[BROKEN COUNT] " .. tostring(broken_count) .. "/" .. tostring(TARGET_BROKEN_COUNT)
        .. " at " .. tostring(x) .. "," .. tostring(y))
end

-- =========================
-- BREAK LOGIC
-- =========================

local function break_until_empty(x, y)
    wait_world()
    return_home()

    local first_fg = get_tile_fg(x, y)

    if first_fg == nil or first_fg == EMPTY_ID then
        return false
    end

    for hit = 1, MAX_HITS_PER_TARGET do
        wait_world()
        return_home()

        local current = get_tile_fg(x, y)

        if current == nil or current == EMPTY_ID then
            add_broken_count(x, y)
            return true
        end

        local ok = pcall(function()
            bot.break_tile(x, y, BREAK_LAYER)
        end)

        if not ok then
            log("[BREAK ERROR] Waiting for world data")
            wait_world()
            return_home()
        end

        rsleep(BREAK_DELAY_MIN, BREAK_DELAY_MAX)
    end

    local after = get_tile_fg(x, y)

    if after == nil or after == EMPTY_ID then
        add_broken_count(x, y)
        return true
    end

    log("[STILL THERE] " .. tostring(x) .. "," .. tostring(y) .. " fg=" .. tostring(after))
    return false
end

clear_all_targets = function()
    local positions = get_pattern_positions()

    log("[CLEAR BEFORE COLLECT] Making sure all 5 target coordinates are empty")

    for pass = 1, MAX_CLEAR_PASSES do
        local all_clear = true

        for _, p in ipairs(positions) do
            if not is_empty(p.x, p.y) then
                all_clear = false
                break_until_empty(p.x, p.y)
            end
        end

        if all_clear then
            log("[ALL CLEAR] All 5 target coordinates are empty")
            return true
        end
    end

    log("[CLEAR WARN] Some target coordinates may still have blocks")
    return false
end

-- =========================
-- RESTOCK / PICKUP
-- =========================

collect_loot = function()
    capture_home_once()
    wait_world()

    log("[COLLECT] Starting pickup route")
    log("[COLLECT] This runs only after clear_all_targets()")

    local world = wait_world()
    local positions = get_pattern_positions()

    for pass = 1, COLLECT_ROUTE_PASSES do
        log("[COLLECT] Pass " .. tostring(pass) .. "/" .. tostring(COLLECT_ROUTE_PASSES))

        return_home()
        sleep(COLLECT_MOVE_WAIT_MS)

        for i = 1, #positions do
            local p = positions[i]

            if in_bounds(world, p.x, p.y) then
                path_to(p.x, p.y)
                sleep(COLLECT_MOVE_WAIT_MS)
            end
        end

        return_home()
        sleep(COLLECT_MOVE_WAIT_MS)

        for i = #positions, 1, -1 do
            local p = positions[i]

            if in_bounds(world, p.x, p.y) then
                path_to(p.x, p.y)
                sleep(COLLECT_MOVE_WAIT_MS)
            end
        end

        if COLLECT_EXTRA_HOME_SWEEP then
            local sweep = {
                {HOME_X, HOME_Y},
                {HOME_X - 1, HOME_Y},
                {HOME_X + 1, HOME_Y},
                {HOME_X, HOME_Y + 1},
                {HOME_X, HOME_Y + 2},
                {HOME_X - 1, HOME_Y + 1},
                {HOME_X + 1, HOME_Y + 1},
                {HOME_X - 1, HOME_Y + 2},
                {HOME_X + 1, HOME_Y + 2}
            }

            for _, s in ipairs(sweep) do
                if in_bounds(world, s[1], s[2]) then
                    path_to(s[1], s[2])
                    sleep(COLLECT_MOVE_WAIT_MS)
                end
            end
        end

        return_home()
        sleep(COLLECT_MOVE_WAIT_MS)
    end

    log("[COLLECT] Pickup route finished")
end

restock = function()
    capture_home_once()
    wait_world()

    log("[RESTOCK] Going to RESTOCK point")
    path_to(RESTOCK_X, RESTOCK_Y)
    sleep(RESTOCK_WAIT_MS)

    local amount = get_inventory_amount(PLACE_ITEM_ID)
    log("[RESTOCK] Current block amount: " .. tostring(amount))

    log("[RESTOCK] Returning HOME")
    return_home()
end

resource_cycle = function(reason)
    if is_resource_cycle_running then
        return
    end

    is_resource_cycle_running = true

    log("[RESOURCE CYCLE] " .. tostring(reason))
    log("[RESOURCE CYCLE] Step 1: clear all target coordinates")
    clear_all_targets()

    log("[RESOURCE CYCLE] Step 2: collect resources")
    collect_loot()

    log("[RESOURCE CYCLE] Step 3: restock blocks")
    restock()

    broken_count = 0
    last_work_time_ms = now_ms()
    last_idle_log_time_ms = last_work_time_ms

    log("[RESOURCE CYCLE] Done. Broken counter reset.")

    is_resource_cycle_running = false
end

finish_broken_cycle_if_needed = function()
    if broken_count >= TARGET_BROKEN_COUNT then
        resource_cycle("target broken count reached")
    end
end

idle_restock_if_needed = function(reason)
    if is_resource_cycle_running then
        return false
    end

    local now = now_ms()
    local idle_for = now - last_work_time_ms

    if idle_for < IDLE_RESTOCK_AFTER_MS then
        if now - last_idle_log_time_ms >= IDLE_RESTOCK_LOG_EVERY_MS then
            last_idle_log_time_ms = now
            log("[IDLE] No place/break work for " .. tostring(math.floor(idle_for / 1000)) .. "s")
        end

        return false
    end

    resource_cycle("idle restock: " .. tostring(reason))
    return true
end

-- =========================
-- PLACE LOGIC
-- =========================

local function place_one(x, y)
    local world = wait_world()

    if not in_bounds(world, x, y) then
        log("[OUT OF BOUNDS] " .. tostring(x) .. "," .. tostring(y))
        return false
    end

    if not is_empty(x, y) then
        return false
    end

    if get_inventory_amount(PLACE_ITEM_ID) <= 0 then
        resource_cycle("no blocks in inventory")
        return false
    end

    return_home()

    if not is_empty(x, y) then
        return false
    end

    local ok = pcall(function()
        bot.place(x, y, PLACE_ITEM_ID, PLACE_LAYER)
    end)

    if ok then
        mark_work("placed block")
        log("[PLACED] at " .. tostring(x) .. "," .. tostring(y))

        if PLACE_DELAY_MS > 0 then
            sleep(PLACE_DELAY_MS)
        end

        return true
    end

    log("[PLACE ERROR] " .. tostring(x) .. "," .. tostring(y))
    return false
end




local function farm_once()
    local positions = get_pattern_positions()
    local did_work = false

    for _, p in ipairs(positions) do
        finish_broken_cycle_if_needed()

        if not is_empty(p.x, p.y) then
            if break_until_empty(p.x, p.y) then
                did_work = true
            end
        end

        finish_broken_cycle_if_needed()

        if is_empty(p.x, p.y) then
            if place_one(p.x, p.y) then
                did_work = true

                if break_until_empty(p.x, p.y) then
                    did_work = true
                end
            end
        end

        finish_broken_cycle_if_needed()
    end

    if not did_work then
        idle_restock_if_needed("mixed no work")
        sleep(NO_WORK_WAIT_MS)
    end
end


-- =========================
-- REJOIN RECOVERY
-- =========================

local function handle_rejoin_recovery()
    if not needs_rejoin_recovery then
        return
    end

    needs_rejoin_recovery = false

    log("[REJOIN RECOVERY] Going to last saved position first")

    if last_known_x ~= nil and last_known_y ~= nil then
        path_to(last_known_x, last_known_y)
    end

    log("[REJOIN RECOVERY] Returning HOME")
    return_home()

    log("[REJOIN RECOVERY] Clear targets first, then collect loot")
    clear_all_targets()
    collect_loot()

    return_home()
    mark_work("rejoin recovery finished")
end

-- =========================
-- MAIN
-- =========================

wait_world()
capture_home_once()

log("[START] MIRAI SOLO FARMER · MIXED PLACE + BREAK · CLEAR BEFORE COLLECT")
log("[INFO] HOME is auto-detected from script start position")
log("[INFO] RESTOCK is 3 tiles left from HOME")
log("[INFO] Before every pickup, all 5 target coordinates are cleared first")

-- First startup rule:
-- 1) Make sure all target coordinates are empty.
-- 2) Then collect resources.
-- 3) Then restock.
clear_all_targets()
collect_loot()
restock()

while true do
    wait_world()
    handle_rejoin_recovery()
    return_home()

    farm_once()

    finish_broken_cycle_if_needed()
    idle_restock_if_needed("main loop")
end
