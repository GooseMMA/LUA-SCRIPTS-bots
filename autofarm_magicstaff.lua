local bot = getBot(SLOT_ID)
if not bot then return end

local BLOCK_ID = 2735

local WORLD = "TEST02"
local STORAGE_WORLD = "GOOSE"
local STORAGE_PORTAL = "qwerty4"

local OWNER = "Snorf"

local MAX_SEEDS = 500
local KEEP_SEEDS = 140

local X_MIN = 0
local X_MAX = 79

local Y_MIN = 3
local Y_MAX = 5

local WALK_Y = 4

local DELAY_HIT = 150
local DELAY_MOVE = 120

-------------------------------------------------
-- INVENTORY
-------------------------------------------------

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

-------------------------------------------------
-- MOVE
-------------------------------------------------

local function go(x, y)
    if bot:isWalkable(x, y) then
        pcall(function()
            bot:find_path(x, y)
        end)
        sleep_ms(DELAY_MOVE)
    end
end

-------------------------------------------------
-- BREAK SEED CLEAN
-------------------------------------------------

local function clean_seeds()

    log("CLEAN SEEDS")

    local w = bot:get_world()

    for x = X_MIN, X_MAX do
        for y = Y_MIN, Y_MAX do

            if y >= Y_MIN and y <= Y_MAX then

                local s = w.seed_at(x, y)

                if s then
                    go(x, y)
                    bot:hit_block(0, 0)
                    sleep_ms(120)
                end
            end
        end
    end

    bot:collectAll()
    sleep_ms(300)
end

-------------------------------------------------
-- BREAK BLOCKS (DO 0)
-------------------------------------------------

local function break_column(x)

    bot:send("HB", {x = x, y = WALK_Y + 1})
    sleep_ms(DELAY_HIT)

    bot:send("HB", {x = x, y = WALK_Y})
    sleep_ms(DELAY_HIT)

    bot:send("HB", {x = x, y = WALK_Y - 1})
    sleep_ms(DELAY_HIT)
end

local function break_all_blocks()

    log("BREAK START")

    while true do

        local blocks = count_items()

        if blocks <= 0 then
            break
        end

        for x = X_MIN, X_MAX do

            if count_items() <= 0 then
                break
            end

            go(x, WALK_Y)
            break_column(x)
        end
    end

    log("BREAK DONE")
end

-------------------------------------------------
-- COLLECT
-------------------------------------------------

local function collect_all()

    bot:collectAll()
    sleep_ms(200)
    bot:collectAll()
end

-------------------------------------------------
-- STORAGE
-------------------------------------------------

local function storage_check()

    local _, seeds = count_items()

    if seeds < MAX_SEEDS then
        return
    end

    local drop = seeds - KEEP_SEEDS

    log("STORAGE:", drop)

    bot:warp(STORAGE_WORLD)
    sleep_ms(3000)

    bot:warp(STORAGE_PORTAL)
    sleep_ms(3000)

    bot:drop(BLOCK_ID, drop, 2)

    sleep_ms(1000)

    bot:warp(WORLD)
    sleep_ms(3000)
end

-------------------------------------------------
-- PLANT
-------------------------------------------------

local function plant_all()

    local _, seeds = count_items()

    log("PLANT START:", seeds)

    for x = X_MIN, X_MAX do

        if seeds <= 0 then break end

        go(x, WALK_Y)

        for y = Y_MIN, Y_MAX do

            if seeds <= 0 then break end

            local w = bot:get_world()
            local tile = bot:get_tile(x, y)

            if tile and tile.fg == 0 then

                bot:plant(x, y, BLOCK_ID)

                seeds = seeds - 1

                sleep_ms(140)
            end
        end
    end

    log("PLANT DONE")
end

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------

bot:connect()
sleep_ms(3000)

bot:warp(WORLD)
sleep_ms(4000)

while true do

    if bot:state() ~= "InWorld" then
        bot:warp(WORLD)
        sleep_ms(4000)
    end

    clean_seeds()

    break_all_blocks()

    collect_all()

    storage_check()

    plant_all()

    collect_all()

    sleep_ms(800)
end