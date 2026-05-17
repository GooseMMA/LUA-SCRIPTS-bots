local bot = getBot(SLOT_ID)

if not bot then
    return
end

bot:off(events.PRESEND)
bot:set_auto_reconnect(true)

math.randomseed(now_ms())

-------------------------------------------------
-- CONFIG
-------------------------------------------------

local BLOCK_ID = 2735

local WORLD = "TEST02"

local STORAGE_WORLD = "GOOSE"
local STORAGE_PORTAL = "qwerty4"

local OWNER = "Snorf"

local MAX_SEEDS = 500
local KEEP_SEEDS = 140

local FIELD_MIN_X = 0
local FIELD_MAX_X = 79

local FIELD_MIN_Y = 3
local FIELD_MAX_Y = 5

local LOCK_X = 40
local LOCK_Y = 5

local PORTAL_X = 40
local PORTAL_Y = 6

local BREAK_DELAY = 200
local WALK_DELAY = 80
local PLANT_DELAY = 70
local HARVEST_DELAY = 120

local REJOIN_DELAY = 3500

local last_log = 0

-------------------------------------------------
-- SAVE
-------------------------------------------------

local SAVE_KEY = "farm_progress_" .. bot:name()

local progress = globalStorage.get(SAVE_KEY) or {
    x = FIELD_MIN_X,
    y = FIELD_MIN_Y
}

local function save_progress(x, y)

    progress.x = x
    progress.y = y

    globalStorage.set(SAVE_KEY, progress)
end

-------------------------------------------------
-- INVENTORY
-------------------------------------------------

local function count_inventory()

    local blocks = 0
    local seeds = 0

    for _, item in ipairs(bot:get_inventory()) do

        if item.id == BLOCK_ID then

            if item.inventory_type == 0 then
                blocks = blocks + item.amount
            end

            if item.inventory_type == 2 then
                seeds = seeds + item.amount
            end
        end
    end

    return blocks, seeds
end

-------------------------------------------------
-- SAFE
-------------------------------------------------

local function blocked_tile(x, y)

    if x == LOCK_X and y == LOCK_Y then
        return true
    end

    if x == PORTAL_X and y == PORTAL_Y then
        return true
    end

    return false
end

-------------------------------------------------
-- STATUS
-------------------------------------------------

local function status()

    local now = now_ms()

    if now - last_log < 60000 then
        return
    end

    last_log = now

    local blocks, seeds = count_inventory()

    log("========== STATUS ==========")
    log("WORLD:", WORLD)
    log("STATE:", bot:state())
    log("BLOCKS:", blocks)
    log("SEEDS:", seeds)
    log("PROGRESS:", progress.x, progress.y)
    log("============================")
end

-------------------------------------------------
-- REJOIN
-------------------------------------------------

local function ensure_world()

    while bot:state() ~= "InWorld" do

        log("NOT IN WORLD:", bot:state())

        sleep_ms(REJOIN_DELAY)

        log("WARPING:", WORLD)

        bot:warp(WORLD)

        sleep_ms(4000)
    end
end

local function refresh_inventory()

    log("REFRESH INVENTORY")

    sleep_ms(REJOIN_DELAY)

    bot:leave()

    sleep_ms(1500)

    bot:warp(WORLD)

    sleep_ms(4000)

    ensure_world()

    log("REJOIN SUCCESS")
end

-------------------------------------------------
-- UNSTUCK
-------------------------------------------------

local function unstuck_check()

    local old = bot:pos()

    sleep_ms(2000)

    local new = bot:pos()

    if old.tile_x == new.tile_x and old.tile_y == new.tile_y then

        log("BOT STUCK -> RESPAWN")

        bot:respawn()

        sleep_ms(1500)
    end
end

-------------------------------------------------
-- AUTO BAN
-------------------------------------------------

bot:on(events.PACKET_RECEIVED, function(pkt)

    for _, id in ipairs(pkt.ids) do

        if id == "AnP" then

            local d = pkt.document

            if not d or not d.m0 then
                return
            end

            local name = d.m0.UN
            local uid = d.m0.U

            if not name or not uid then
                return
            end

            if name == OWNER then
                return
            end

            bot:world_ban(uid)

            log("BANNED:", name)
        end
    end
end)

-------------------------------------------------
-- STORAGE
-------------------------------------------------

local function storage_check()

    local _, seeds = count_inventory()

    if seeds < MAX_SEEDS then
        return
    end

    local drop_amount = seeds - KEEP_SEEDS

    if drop_amount <= 0 then
        return
    end

    log("STORAGE MODE")

    bot:warp(STORAGE_WORLD)

    sleep_ms(4000)

    bot:warp(STORAGE_PORTAL)

    sleep_ms(4000)

    bot:drop(BLOCK_ID, drop_amount, 2)

    sleep_ms(1000)

    bot:warp(WORLD)

    sleep_ms(4000)

    ensure_world()
end

-------------------------------------------------
-- SMART COLLECT
-------------------------------------------------

local function smart_collect()

    local before = #bot:get_collectables()

    bot:collectAll()

    sleep_ms(150)

    local after = #bot:get_collectables()

    if after >= before then

        bot:collectAll()

        sleep_ms(250)
    end
end

-------------------------------------------------
-- BREAK TREE
-------------------------------------------------

local function break_tree(x, y)

    for i = 1, 3 do

        bot:send("HB", {
            x = x,
            y = y
        })

        sleep_ms(HARVEST_DELAY)

        local tile = bot:get_tile(x, y)

        if tile and tile.fg == 0 then
            return true
        end
    end

    return false
end

-------------------------------------------------
-- COLLECT TILE
-------------------------------------------------

local function collect_tile(x, y)

    local tile = bot:get_tile(x, y)

    if tile and tile.fg ~= 0 then

        bot:send("HB", {
            x = x,
            y = y
        })

        sleep_ms(200)
    end

    local points = {
        {x, y + 1},
        {x - 1, y + 1},
        {x + 1, y + 1}
    }

    for _, p in ipairs(points) do

        if bot:isWalkable(p[1], p[2]) then

            pcall(function()
                bot:find_path(p[1], p[2])
            end)

            sleep_ms(WALK_DELAY)

            smart_collect()

            sleep_ms(100)
        end
    end
end

-------------------------------------------------
-- WORLD CLEANUP
-------------------------------------------------

local function cleanup_world()

    log("WORLD CLEANUP")

    for y = FIELD_MIN_Y, FIELD_MAX_Y do

        for x = FIELD_MIN_X, FIELD_MAX_X do

            if blocked_tile(x, y) then
                goto continue
            end

            local tile = bot:get_tile(x, y)

            if tile and tile.fg ~= 0 then

                local walk_y = y + 1

                if bot:isWalkable(x, walk_y) then

                    pcall(function()
                        bot:find_path(x, walk_y)
                    end)

                    sleep_ms(WALK_DELAY)
                end

                break_tree(x, y)

                collect_tile(x, y)
            end

            ::continue::
        end
    end

    refresh_inventory()
end

-------------------------------------------------
-- PLANT
-------------------------------------------------

local function plant_all()

    local _, seeds = count_inventory()

    if seeds <= 0 then
        return
    end

    for x = FIELD_MIN_X, FIELD_MAX_X do

        local stand_x = x
        local stand_y = FIELD_MAX_Y + 1

        if bot:isWalkable(stand_x, stand_y) then

            pcall(function()
                bot:find_path(stand_x, stand_y)
            end)

            sleep_ms(WALK_DELAY)

            unstuck_check()
        end

        for y = FIELD_MIN_Y, FIELD_MAX_Y do

            save_progress(x, y)

            if seeds <= 0 then

                log("SEEDS EMPTY")

                refresh_inventory()

                return
            end

            if blocked_tile(x, y) then
                goto continue
            end

            local tile = bot:get_tile(x, y)

            if tile and tile.fg == 0 then

                bot:plant(x, y, BLOCK_ID)

                seeds = seeds - 1

                sleep_ms(PLANT_DELAY)
            end

            ::continue::
        end
    end

    refresh_inventory()
end

-------------------------------------------------
-- READY CHECK
-------------------------------------------------

local function all_ready()

    local w = bot:get_world()

    for y = FIELD_MIN_Y, FIELD_MAX_Y do
        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not blocked_tile(x, y) then

                local s = w.seed_at(x, y)

                if s and not s.ready then
                    return false
                end
            end
        end
    end

    return true
end

-------------------------------------------------
-- HARVEST
-------------------------------------------------

local function harvest_all()

    log("WAITING READY")

    while not all_ready() do
        sleep_ms(5000)
    end

    log("HARVEST START")

    bot:set_auto_collect(true, 200)

    for y = FIELD_MIN_Y, FIELD_MAX_Y do

        for x = FIELD_MIN_X, FIELD_MAX_X do

            save_progress(x, y)

            if blocked_tile(x, y) then
                goto continue
            end

            local s = bot:get_world().seed_at(x, y)

            if s and s.ready then

                local walk_y = y + 1

                if bot:isWalkable(x, walk_y) then

                    pcall(function()
                        bot:find_path(x, walk_y)
                    end)

                    sleep_ms(WALK_DELAY)

                    unstuck_check()
                end

                break_tree(x, y)

                collect_tile(x, y)
            end

            ::continue::
        end
    end

    bot:set_auto_collect(false)

    refresh_inventory()
end

-------------------------------------------------
-- INSTA BREAK
-------------------------------------------------

local function burst(x, y)

    for i = 1, 30 do

        bot:send("SB", {
            x = x,
            y = y,
            BlockType = BLOCK_ID
        })

        for j = 1, 4 do

            bot:send("HB", {
                x = x,
                y = y
            })
        end
    end
end

-------------------------------------------------
-- SPAWN COLLECT
-------------------------------------------------

local function collect_spawn()

    local p = bot:pos()

    local targets = {
        {p.tile_x - 1, p.tile_y + 1},
        {p.tile_x,     p.tile_y + 1},
        {p.tile_x + 1, p.tile_y + 1}
    }

    log("CHECKING LEFTOVER")

    for _, t in ipairs(targets) do

        local x = t[1]
        local y = t[2]

        local tile = bot:get_tile(x, y)

        if tile and tile.fg ~= 0 then

            bot:send("HB", {
                x = x,
                y = y
            })

            sleep_ms(200)
        end
    end

    local sx = p.tile_x
    local sy = p.tile_y

    local path = {

        {sx, sy - 1},

        {sx + 1, sy - 1},

        {sx - 1, sy - 1},

        {sx - 1, sy - 1},

        {sx, sy}
    }

    for _, pos in ipairs(path) do

        if bot:isWalkable(pos[1], pos[2]) then

            pcall(function()
                bot:find_path(pos[1], pos[2])
            end)

            sleep_ms(WALK_DELAY)

            smart_collect()

            sleep_ms(120)
        end
    end
end

-------------------------------------------------
-- INSTA BREAK CYCLE
-------------------------------------------------

local function break_cycle()

    local blocks = count_inventory()

    if blocks <= 0 then
        return
    end

    log("INSTA BREAK START")

    local p = bot:pos()

    burst(p.tile_x - 1, p.tile_y + 1)

    sleep_ms(BREAK_DELAY + math.random(0, 40))

    burst(p.tile_x, p.tile_y + 1)

    sleep_ms(BREAK_DELAY + math.random(0, 40))

    burst(p.tile_x + 1, p.tile_y + 1)

    sleep_ms(BREAK_DELAY + math.random(0, 40))

    log("BREAK DONE -> REJOIN")

    refresh_inventory()

    collect_spawn()

    refresh_inventory()

    log("INSTA BREAK FINISHED")
end

-------------------------------------------------
-- START
-------------------------------------------------

bot:connect()

sleep_ms(3000)

bot:warp(WORLD)

sleep_ms(4000)

ensure_world()

cleanup_world()

while true do

    ensure_world()

    status()

    storage_check()

    local blocks, seeds = count_inventory()

    if seeds > 0 then

        plant_all()

        harvest_all()
    end

    blocks, seeds = count_inventory()

    if blocks > 0 then
        break_cycle()
    end

    sleep_ms(1000)
end