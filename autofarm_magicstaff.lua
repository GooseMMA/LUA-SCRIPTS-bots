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

local last_log = 0

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

local function can_plant(x, y)

    if x == LOCK_X and y == LOCK_Y then
        return false
    end

    if x == PORTAL_X and y == PORTAL_Y then
        return false
    end

    return true
end

local function ensure_world()

    while bot:state() ~= "InWorld" do
        bot:warp(WORLD)
        sleep_ms(4000)
    end
end

local function walk_to(x, y)

    local ok = pcall(function()
        bot:find_path(x, y)
    end)

    if ok then
        sleep_ms(120)
    end
end

local function plant_all()

    log("PLANT START")

    for y = FIELD_MIN_Y, FIELD_MAX_Y do

        walk_to(1, y)

        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not can_plant(x, y) then
                goto continue
            end

            local _, seeds = count_inv()

            if seeds <= 0 then
                return
            end

            walk_to(x, y + 1)

            local tile = bot:get_tile(x, y)

            if tile and tile.fg == 0 then

                bot:plant(x, y, BLOCK_ID)

                sleep_ms(70)
            end

            ::continue::
        end
    end

    log("PLANT END")
end

local function all_ready()

    local w = bot:get_world()

    for y = FIELD_MIN_Y, FIELD_MAX_Y do
        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not can_plant(x, y) then
                goto continue
            end

            local s = w.seed_at(x, y)

            if s and not s.ready then
                return false
            end

            ::continue::
        end
    end

    return true
end

local function wait_growth()

    log("WAIT GROWTH")

    bot:respawn()

    while true do

        ensure_world()

        if all_ready() then
            log("ALL READY")
            return
        end

        sleep_ms(5000)
    end
end

local function harvest_all()

    log("HARVEST START")

    bot:set_auto_collect(true, 200)

    for y = FIELD_MIN_Y, FIELD_MAX_Y do

        walk_to(1, y + 1)

        for x = FIELD_MIN_X, FIELD_MAX_X do

            if not can_plant(x, y) then
                goto continue
            end

            local w = bot:get_world()
            local s = w.seed_at(x, y)

            if s and s.ready then

                walk_to(x, y + 1)

                for i = 1, 4 do

                    bot:send("HB", {
                        x = x,
                        y = y
                    })

                    sleep_ms(70)
                end

                sleep_ms(150)

                bot:collectAll()

                sleep_ms(100)
            end

            ::continue::
        end
    end

    bot:set_auto_collect(false)

    log("HARVEST END")
end

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

local function break_spawn()

    bot:respawn()

    sleep_ms(1000)

    local p = bot:pos()

    local px = p.tile_x
    local py = p.tile_y

    burst(px - 1, py - 1)
    burst(px, py - 1)
    burst(px + 1, py - 1)

    sleep_ms(2500)

    bot:leave()

    sleep_ms(4000)

    bot:warp(WORLD)

    sleep_ms(5000)

    walk_to(px - 1, py)
    bot:collectAll()

    walk_to(px, py)
    bot:collectAll()

    walk_to(px + 1, py)
    bot:collectAll()

    walk_to(px, py)

    sleep_ms(300)
end

local function do_storage(seeds)

    if seeds < MAX_SEEDS then
        return
    end

    log("STORAGE START")

    bot:warp(STORAGE_WORLD)

    sleep_ms(4000)

    bot:warp(STORAGE_PORTAL)

    sleep_ms(4000)

    local drop = seeds - KEEP_AMOUNT

    if drop > 0 then

        bot:drop(BLOCK_ID, drop, 2)

        sleep_ms(1000)
    end

    bot:warp(WORLD)

    sleep_ms(4000)

    log("STORAGE END")
end

local function setup_ban()

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

                pcall(function()
                    bot:world_ban(uid)
                end)
            end
        end
    end)
end

local function log_status()

    local now = now_ms()

    if now - last_log < 60000 then
        return
    end

    last_log = now

    local blocks, seeds = count_inv()

    log("========== STATUS ==========")
    log("WORLD:", WORLD)
    log("STATE:", bot:state())
    log("BLOCKS:", blocks)
    log("SEEDS:", seeds)
    log("============================")
end

local function main()

    setup_ban()

    bot:connect()

    sleep_ms(3000)

    bot:warp(WORLD)

    sleep_ms(5000)

    while true do

        ensure_world()

        log_status()

        local blocks, seeds = count_inv()

        if seeds > MAX_SEEDS then
            do_storage(seeds)
        end

        if blocks > 0 then
            break_spawn()
        end

        local _, current_seeds = count_inv()

        if current_seeds > 0 then

            plant_all()

            wait_growth()

            harvest_all()
        else
            sleep_ms(5000)
        end
    end
end

main()