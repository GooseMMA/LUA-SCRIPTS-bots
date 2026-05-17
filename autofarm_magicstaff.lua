local bot = getBot(SLOT_ID)

if not bot then return end

bot:off(events.PRESEND)

local BLOCK_ID = 2735

local WORLD = "TEST02"
local STORAGE_WORLD = "GOOSE"
local STORAGE_PORTAL = "qwerty4"

local OWNER = "Snorf"

local MAX_SEEDS = 500
local KEEP_AMOUNT = 140

local FIELD_MIN_X = 0
local FIELD_MAX_X = 79
local FIELD_MIN_Y = 3
local FIELD_MAX_Y = 5

local LOCK_X, LOCK_Y = 40, 5
local PORTAL_X, PORTAL_Y = 40, 6

local BREAK_DELAY = 200
local MOVE_DELAY = 120
local RECONNECT_DELAY = 200

local last_log = 0

-------------------------------------------------
-- INVENTORY
-------------------------------------------------

local function count_inv()

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
-- SAFE TILE CHECK
-------------------------------------------------

local function can_plant(x, y)

    if x == LOCK_X and y == LOCK_Y then
        return false
    end

    if x == PORTAL_X and y == PORTAL_Y then
        return false
    end

    return true
end

-------------------------------------------------
-- RECONNECT
-------------------------------------------------

local function ensure_world()

    while bot:state() ~= "InWorld" do

        local st = bot:state()

        if st == "Failed" then

            bot:leave()
            sleep_ms(RECONNECT_DELAY)

            bot:warp(WORLD)
            sleep_ms(3500)

        elseif st == "MenuIdle" then

            bot:warp(WORLD)
            sleep_ms(3500)

        else
            sleep_ms(RECONNECT_DELAY)
        end
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

            if name == OWNER then
                return
            end

            bot:world_ban(uid)
        end
    end
end)

-------------------------------------------------
-- LOG STATUS
-------------------------------------------------

local function log_status(blocks, seeds)

    local now = now_ms()

    if now - last_log < 60000 then
        return
    end

    last_log = now

    log("========== FARM ==========")
    log("WORLD:", WORLD)
    log("STATE:", bot:state())
    log("BLOCKS:", blocks)
    log("SEEDS:", seeds)
    log("==========================")
end

-------------------------------------------------
-- FAST BREAK
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

local function cleanup_block(x, y)

    local t = bot:get_tile(x, y)

    if t and t.fg ~= 0 then

        for i = 1, 4 do

            bot:send("HB", {
                x = x,
                y = y
            })

            sleep_ms(50)
        end
    end
end

local function collect_spawn()

    local p = bot:pos()

    local targets = {
        {x = p.tile_x - 1, y = p.tile_y - 1},
        {x = p.tile_x,     y = p.tile_y - 1},
        {x = p.tile_x + 1, y = p.tile_y - 1}
    }

    for _, v in ipairs(targets) do

        cleanup_block(v.x, v.y)

        local walk_x = v.x
        local walk_y = v.y + 1

        pcall(function()
            bot:find_path(walk_x, walk_y)
        end)

        sleep_ms(MOVE_DELAY)

        bot:collect_at(v.x, v.y)
        bot:collectAll()

        sleep_ms(MOVE_DELAY)
    end
end

local function break_spawn()

    local p = bot:pos()

    burst(p.tile_x - 1, p.tile_y - 1)
    burst(p.tile_x,     p.tile_y - 1)
    burst(p.tile_x + 1, p.tile_y - 1)

    sleep_ms(BREAK_DELAY)

    bot:leave()
    sleep_ms(RECONNECT_DELAY)

    bot:warp(WORLD)
    sleep_ms(3500)

    ensure_world()

    collect_spawn()
end

-------------------------------------------------
-- PLANT
-------------------------------------------------

local function plant_all()

    for y = FIELD_MIN_Y, FIELD_MAX_Y do
        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not can_plant(x, y) then
                goto continue
            end

            if not bot:has_item(BLOCK_ID) then
                return
            end

            local walk_y = y + 1

            pcall(function()
                bot:find_path(x, walk_y)
            end)

            sleep_ms(MOVE_DELAY)

            bot:plant(x, y, BLOCK_ID)

            sleep_ms(200)

            ::continue::
        end
    end
end

-------------------------------------------------
-- READY CHECK
-------------------------------------------------

local function all_ready()

    local w = bot:get_world()

    for y = FIELD_MIN_Y, FIELD_MAX_Y do
        for x = FIELD_MIN_X, FIELD_MAX_X do

            if can_plant(x, y) then

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
-- TREE CHECK
-------------------------------------------------

local function is_tree(tile)

    if not tile then
        return false
    end

    return tile.fg ~= 0
end

-------------------------------------------------
-- HARVEST
-------------------------------------------------

local function harvest_all()

    bot:set_auto_collect(true, 250)

    for y = FIELD_MIN_Y, FIELD_MAX_Y do
        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not can_plant(x, y) then
                goto continue
            end

            local tile = bot:get_tile(x, y)
            local seed = bot:get_world().seed_at(x, y)

            if seed and seed.ready and is_tree(tile) then

                local walk_y = y + 1

                pcall(function()
                    bot:find_path(x, walk_y)
                end)

                sleep_ms(MOVE_DELAY)

                bot:hit(x, y)

                sleep_ms(120)

                bot:collect_at(x, y)
                bot:collectAll()

                sleep_ms(MOVE_DELAY)
            end

            ::continue::
        end
    end

    bot:set_auto_collect(false)
end

-------------------------------------------------
-- STORAGE
-------------------------------------------------

local function do_storage(seeds)

    if seeds < MAX_SEEDS then
        return
    end

    local drop = seeds - KEEP_AMOUNT

    if drop <= 0 then
        return
    end

    bot:warp(STORAGE_WORLD)
    sleep_ms(3500)

    bot:warp(STORAGE_PORTAL)
    sleep_ms(3500)

    ensure_world()

    bot:drop(BLOCK_ID, drop, 2)

    sleep_ms(1000)

    bot:warp(WORLD)
    sleep_ms(3500)

    ensure_world()
end

-------------------------------------------------
-- MAIN
-------------------------------------------------

bot:connect()
sleep_ms(3000)

bot:warp(WORLD)
sleep_ms(4000)

ensure_world()

while true do

    ensure_world()

    local blocks, seeds = count_inv()

    log_status(blocks, seeds)

    do_storage(seeds)

    blocks, seeds = count_inv()

    if blocks > 0 then

        break_spawn()

        sleep_ms(200)
    end

    blocks, seeds = count_inv()

    if seeds > 0 then

        plant_all()

        while not all_ready() do

            sleep_ms(5000)

            ensure_world()
        end

        harvest_all()

        sleep_ms(500)

    else

        sleep_ms(3000)
    end
end