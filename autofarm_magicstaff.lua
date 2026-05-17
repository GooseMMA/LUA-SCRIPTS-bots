local bot = getBot(SLOT_ID)

if not bot then
    return
end

bot:off(events.PRESEND)
bot:set_auto_reconnect(true)

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
local WALK_DELAY = 90
local PLANT_DELAY = 70
local HARVEST_DELAY = 120

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
    log("============================")
end

-------------------------------------------------
-- REJOIN
-------------------------------------------------

local function ensure_world()
    while bot:state() ~= "InWorld" do
        bot:warp(WORLD)
        sleep_ms(4000)
    end
end

local function refresh_inventory()
    bot:leave()
    sleep_ms(1000)

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
-- BREAK
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

    local points = {
        { p.tile_x - 1, p.tile_y + 1 },
        { p.tile_x,     p.tile_y + 1 },
        { p.tile_x + 1, p.tile_y + 1 }
    }

    for _, v in ipairs(points) do

        local x = v[1]
        local y = v[2]

        local tile = bot:get_tile(x, y)

        if tile and tile.fg ~= 0 then
            bot:send("HB", { x = x, y = y })
            sleep_ms(200)
        end
    end

    local walk_points = {
        { p.tile_x - 1, p.tile_y },
        { p.tile_x,     p.tile_y },
        { p.tile_x + 1, p.tile_y }
    }

    for _, v in ipairs(walk_points) do
        bot:find_path(v[1], v[2])
        sleep_ms(WALK_DELAY)
        bot:collectAll()
        sleep_ms(100)
    end

    bot:find_path(p.tile_x, p.tile_y)
end

local function break_cycle()

    local blocks = count_inventory()

    if blocks <= 0 then
        return
    end

    local p = bot:pos()

    burst(p.tile_x - 1, p.tile_y + 1)
    sleep_ms(BREAK_DELAY)

    burst(p.tile_x, p.tile_y + 1)
    sleep_ms(BREAK_DELAY)

    burst(p.tile_x + 1, p.tile_y + 1)
    sleep_ms(BREAK_DELAY)

    refresh_inventory()

    collect_spawn()
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
        end

        for y = FIELD_MIN_Y, FIELD_MAX_Y do

            if seeds <= 0 then
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

    for x = FIELD_MIN_X, FIELD_MAX_X do
        for y = FIELD_MIN_Y, FIELD_MAX_Y do

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

    while not all_ready() do
        sleep_ms(5000)
    end

    bot:set_auto_collect(true, 200)

    for x = FIELD_MIN_X, FIELD_MAX_X do

        local stand_x = x
        local stand_y = FIELD_MAX_Y + 1

        if bot:isWalkable(stand_x, stand_y) then
            pcall(function()
                bot:find_path(stand_x, stand_y)
            end)

            sleep_ms(WALK_DELAY)
        end

        for y = FIELD_MIN_Y, FIELD_MAX_Y do

            if blocked_tile(x, y) then
                goto continue
            end

            local s = bot:get_world().seed_at(x, y)

            if s and s.ready then
                bot:send("HB", {
                    x = x,
                    y = y
                })

                sleep_ms(HARVEST_DELAY)

                bot:collectAll()

                sleep_ms(90)
            end

            ::continue::
        end
    end

    bot:set_auto_collect(false)

    refresh_inventory()
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

    if blocks > 0 then
        break_cycle()
    end

    blocks, seeds = count_inventory()

    if seeds > 0 then
        plant_all()
        harvest_all()
    else
        sleep_ms(3000)
    end
end