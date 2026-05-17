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

local WALK_Y = 4

local LOCK_X = 40
local LOCK_Y = 5

local PORTAL_X = 40
local PORTAL_Y = 6

local WALK_DELAY = 45
local PLANT_DELAY = 60
local BREAK_DELAY = 85

local REJOIN_DELAY = 3500

local last_log = 0

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
            elseif item.inventory_type == 2 then
                seeds = seeds + item.amount
            end
        end
    end

    return blocks, seeds
end

-------------------------------------------------
-- SAFE TILE
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
    log("============================")
end

-------------------------------------------------
-- WORLD CHECK
-------------------------------------------------

local function ensure_world()

    while bot:state() ~= "InWorld" do

        log("REJOIN:", bot:state())

        sleep_ms(REJOIN_DELAY)

        bot:warp(WORLD)

        sleep_ms(4000)
    end
end

local function refresh_inventory()

    log("REFRESH INVENTORY")

    sleep_ms(REJOIN_DELAY)

    bot:leave()

    sleep_ms(1200)

    bot:warp(WORLD)

    sleep_ms(4000)

    ensure_world()
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

    log("STORAGE")

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

    bot:collectAll()

    sleep_ms(120)

    bot:collectAll()
end

-------------------------------------------------
-- PLANT
-------------------------------------------------

local function plant_all()

    local _, seeds = count_inventory()

    if seeds <= 0 then
        return
    end

    log("PLANT START")

    for x = FIELD_MIN_X, FIELD_MAX_X do

        if seeds <= 0 then
            break
        end

        local walk_y = WALK_Y

        if bot:isWalkable(x, walk_y) then

            pcall(function()
                bot:find_path(x, walk_y)
            end)

            sleep_ms(WALK_DELAY)
        end

        for y = FIELD_MIN_Y, FIELD_MAX_Y do

            if seeds <= 0 then
                break
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

    log("PLANT DONE")
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
-- FAST HARVEST
-------------------------------------------------

local function harvest_column(x)

    bot:send("HB", {
        x = x,
        y = 3
    })

    bot:send("HB", {
        x = x,
        y = 4
    })

    bot:send("HB", {
        x = x,
        y = 5
    })
end

local function collect_world()

    log("COLLECT START")

    local collectables = bot:get_collectables()

    for _, obj in ipairs(collectables) do

        local cx = math.floor(obj.x / 32)
        local cy = math.floor(obj.y / 32)

        local walk_y = cy + 1

        if bot:isWalkable(cx, walk_y) then

            pcall(function()
                bot:find_path(cx, walk_y)
            end)

            sleep_ms(WALK_DELAY)

            smart_collect()

            sleep_ms(80)
        end
    end

    smart_collect()

    log("COLLECT DONE")
end

local function harvest_all()

    log("WAIT READY")

    while not all_ready() do
        sleep_ms(5000)
    end

    log("FAST HARVEST")

    for x = FIELD_MIN_X, FIELD_MAX_X do

        local walk_y = WALK_Y

        if bot:isWalkable(x, walk_y) then

            pcall(function()
                bot:find_path(x, walk_y)
            end)

            sleep_ms(WALK_DELAY)
        end

        harvest_column(x)

        sleep_ms(BREAK_DELAY)
    end

    sleep_ms(1500)

    collect_world()

    bot:respawn()

    sleep_ms(1000)

    refresh_inventory()

    log("HARVEST DONE")
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

local function collect_spawn()

    local p = bot:pos()

    local sx = p.tile_x
    local sy = p.tile_y

    local path = {

        {sx, sy + 1},

        {sx + 1, sy + 1},

        {sx - 1, sy + 1},

        {sx, sy}
    }

    for _, pos in ipairs(path) do

        if bot:isWalkable(pos[1], pos[2]) then

            pcall(function()
                bot:find_path(pos[1], pos[2])
            end)

            sleep_ms(WALK_DELAY)

            smart_collect()

            sleep_ms(80)
        end
    end
end

local function break_cycle()

    local blocks = count_inventory()

    if blocks <= 0 then
        return
    end

    log("INSTA BREAK")

    local p = bot:pos()

    burst(p.tile_x - 1, p.tile_y + 1)

    sleep_ms(200)

    burst(p.tile_x, p.tile_y + 1)

    sleep_ms(200)

    burst(p.tile_x + 1, p.tile_y + 1)

    sleep_ms(200)

    refresh_inventory()

    collect_spawn()

    refresh_inventory()

    log("BREAK DONE")
end

-------------------------------------------------
-- START
-------------------------------------------------

bot:connect()

sleep_ms(3000)

bot:warp(WORLD)

sleep_ms(4000)

ensure_world()

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