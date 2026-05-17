local bot = getBot(SLOT_ID)

if not bot then
    return
end

bot:off(events.PRESEND)
bot:off(events.PACKET_RECEIVED)

local WORLD_NAME = "TEST02"
local STORAGE_WORLD = "GOOSE"
local STORAGE_PORTAL = "qwerty4"

local BLOCK_ID = 2735

local STACK_COUNT = 30
local HITS_PER_BLOCK = 4

local FARM_Y_START = 3
local FARM_Y_END = 5

local WORLD_MIN_X = 0
local WORLD_MAX_X = 79

local SEED_KEEP = 140
local SEED_DROP_AMOUNT = 360
local SEED_DROP_THRESHOLD = 500

local STATUS_INTERVAL = 60000

local WHITELIST = {
    ["Snorf"] = true
}

local running = false

local stats = {
    cycles = 0,
    planted = 0,
    harvested = 0,
    dropped = 0,
    start = now_ms()
}

local function count_items()

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

local function print_status()

    local blocks, seeds = count_items()

    local uptime = math.floor((now_ms() - stats.start) / 60000)

    log("========== FARM STATUS ==========")
    log("WORLD:", tostring(bot:get_world_name()))
    log("STATE:", bot:state())
    log("BLOCKS:", blocks)
    log("SEEDS:", seeds)
    log("CYCLES:", stats.cycles)
    log("PLANTED:", stats.planted)
    log("HARVESTED:", stats.harvested)
    log("SEEDS DROPPED:", stats.dropped)
    log("UPTIME:", uptime .. "m")
    log("=================================")
end

task.spawn(function()

    while true do
        sleep_ms(STATUS_INTERVAL)
        print_status()
    end
end)

bot:on(events.PACKET_RECEIVED, function(pkt)

    for _, id in ipairs(pkt.ids) do

        if id == "AnP" then

            if pkt.document
            and pkt.document["m0"]
            and pkt.document["m0"]["UN"] then

                local username = pkt.document["m0"]["UN"]
                local userId = pkt.document["m0"]["U"]

                if not WHITELIST[username] then
                    pcall(function()
                        bot:world_ban(userId)
                    end)
                end
            end
        end
    end
end)

local function ensure_world(world)

    while bot:state() ~= "InWorld" do

        if bot:state() == "Failed" then
            bot:connect()
        end

        if bot:state() == "MenuIdle" then
            bot:warp(world)
        end

        sleep_ms(3000)
    end
end

local function warp(world)

    pcall(function()
        bot:warp(world)
    end)

    ensure_world(world)

    sleep_ms(4000)
end

local function burst(x, y)

    for i = 1, STACK_COUNT do

        bot:send("SB", {
            x = x,
            y = y,
            BlockType = BLOCK_ID
        })

        for j = 1, HITS_PER_BLOCK do

            bot:send("HB", {
                x = x,
                y = y
            })
        end
    end
end

local function ensure_break(x, y)

    local tile = bot:get_tile(x, y)

    if tile and tile.fg ~= 0 then

        for i = 1, 4 do

            bot:send("HB", {
                x = x,
                y = y
            })

            sleep_ms(200)
        end
    end
end

local function fast_collect(x, y)

    ensure_break(x, y)

    pcall(function()
        bot:find_path(x, y)
    end)

    sleep_ms(150)

    bot:collectAll()

    sleep_ms(150)
end

local function do_break_cycle()

    local pos = bot:pos()

    local px = pos.tile_x
    local py = pos.tile_y

    burst(px - 1, py + 1)
    burst(px, py + 1)
    burst(px + 1, py + 1)

    sleep_ms(3500)

    bot:leave()

    sleep_ms(5000)

    warp(WORLD_NAME)

    fast_collect(px - 1, py + 1)
    fast_collect(px, py + 1)
    fast_collect(px + 1, py + 1)

    pcall(function()
        bot:find_path(px, py)
    end)

    sleep_ms(300)

    stats.cycles = stats.cycles + 1
end

local function is_blocked_tile(x, y)

    if x == 40 and y == 5 then
        return true
    end

    if x == 40 and y == 6 then
        return true
    end

    return false
end

local function plant_seeds()

    local _, seeds = count_items()

    if seeds <= 0 then
        return
    end

    local planted = 0

    for y = FARM_Y_START, FARM_Y_END do

        for x = WORLD_MIN_X, WORLD_MAX_X do

            if planted >= 239 then
                return
            end

            local _, current_seeds = count_items()

            if current_seeds <= 0 then
                return
            end

            if not is_blocked_tile(x, y) then

                local tile = bot:get_tile(x, y)

                if tile and tile.fg == 0 then

                    pcall(function()
                        bot:plant(x, y, BLOCK_ID)
                    end)

                    planted = planted + 1
                    stats.planted = stats.planted + 1

                    sleep_ms(120)
                end
            end
        end
    end
end

local function all_ready()

    local w = bot:get_world()

    for _, seed in ipairs(w.seeds) do

        if not is_blocked_tile(seed.x, seed.y) then

            if not seed.ready then
                return false
            end
        end
    end

    return true
end

local function wait_growth()

    bot:respawn()

    while true do

        if all_ready() then
            break
        end

        sleep_ms(5000)
    end
end

local function harvest_seed(x, y)

    ensure_break(x, y)

    for i = 1, 4 do

        bot:send("HB", {
            x = x,
            y = y
        })

        sleep_ms(120)
    end

    fast_collect(x, y)

    stats.harvested = stats.harvested + 1
end

local function harvest_all()

    for y = FARM_Y_START, FARM_Y_END do

        for x = WORLD_MIN_X, WORLD_MAX_X do

            if not is_blocked_tile(x, y) then

                local seed = bot:get_world().seed_at(x, y)

                if seed and seed.ready then

                    pcall(function()
                        bot:find_path(x, y)
                    end)

                    sleep_ms(120)

                    harvest_seed(x, y)
                end
            end
        end
    end
end

local function storage_drop()

    local _, seeds = count_items()

    if seeds < SEED_DROP_THRESHOLD then
        return
    end

    warp(STORAGE_WORLD)

    pcall(function()
        bot:warp(STORAGE_PORTAL)
    end)

    sleep_ms(5000)

    local _, now_seeds = count_items()

    local drop_amount = math.min(SEED_DROP_AMOUNT, now_seeds - SEED_KEEP)

    if drop_amount > 0 then

        pcall(function()
            bot:drop(BLOCK_ID, drop_amount, 2)
        end)

        stats.dropped = stats.dropped + drop_amount

        sleep_ms(1000)
    end

    warp(WORLD_NAME)
end

warp(WORLD_NAME)

bot:on(events.PRESEND, function()

    if running then
        return
    end

    running = true

    while true do

        ensure_world(WORLD_NAME)

        local blocks, seeds = count_items()

        if blocks > 0 then

            do_break_cycle()

        elseif seeds > 0 then

            plant_seeds()

            wait_growth()

            harvest_all()

            storage_drop()

        else

            sleep_ms(10000)
        end
    end
end)

while true do
    sleep_ms(1000)
end