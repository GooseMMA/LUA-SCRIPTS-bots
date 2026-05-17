local bot = getBot(SLOT_ID)
if not bot then return end

-------------------------------------------------
-- CONFIG
-------------------------------------------------

local WORLD = "TEST02"
local BLOCK_ID = 2735

local X1, X2 = 0, 79
local Y1, Y2 = 3, 5

local LOCK_X, LOCK_Y = 40, 5
local PORTAL_X, PORTAL_Y = 40, 6

local RECONNECT_DELAY = 3000

-------------------------------------------------
-- SAFE TILE
-------------------------------------------------

local function safe(x, y)
    if x == LOCK_X and y == LOCK_Y then return false end
    if x == PORTAL_X and y == PORTAL_Y then return false end
    return true
end

-------------------------------------------------
-- CONNECT
-------------------------------------------------

local function ensure()
    while bot:state() ~= "InWorld" do
        if bot:state() == "Failed" then
            bot:connect()
        elseif bot:state() == "MenuIdle" then
            bot:warp(WORLD)
        end
        sleep_ms(RECONNECT_DELAY)
    end
end

-------------------------------------------------
-- INVENTORY
-------------------------------------------------

local function count_blocks()
    local blocks = 0
    for _, item in ipairs(bot:get_inventory()) do
        if item.id == BLOCK_ID and item.inventory_type == 0 then
            blocks = blocks + item.amount
        end
    end
    return blocks
end

-------------------------------------------------
-- MOVE
-------------------------------------------------

local function go(x, y)
    if bot:isWalkable(x, y) then
        bot:find_path(x, y)
        sleep_ms(150)
    end
end

-------------------------------------------------
-- 1. INSTA BREAK ALL BLOCKS
-------------------------------------------------

local function break_all_blocks()

    ensure()

    while true do

        local blocks = count_blocks()
        if blocks <= 0 then break end

        local p = bot:pos()
        local x, y = p.tile_x, p.tile_y

        -- ломаем вокруг позиции (инста)
        local function burst(tx, ty)
            for i = 1, 30 do
                bot:send("SB", {
                    x = tx,
                    y = ty,
                    BlockType = BLOCK_ID
                })
                for j = 1, 4 do
                    bot:send("HB", {x = tx, y = ty})
                end
            end
        end

        burst(x - 1, y - 1)
        burst(x, y - 1)
        burst(x + 1, y - 1)

        sleep_ms(200)
    end
end

-------------------------------------------------
-- 2. PLANT SEEDS
-------------------------------------------------

local function plant_all()

    ensure()

    for y = Y1, Y2 do
        for x = X1, X2 do

            if safe(x, y) then

                local w = bot:get_world()

                if w:fg_at(x, y) == 0 and bot:has_item(BLOCK_ID) then
                    go(x, y)
                    sleep_ms(120)

                    bot:plant(x, y, BLOCK_ID)
                    sleep_ms(120)
                end

            end

        end
    end
end

-------------------------------------------------
-- 3. WAIT GROWTH
-------------------------------------------------

local function wait_grow()

    ensure()

    while true do

        local w = bot:get_world()
        local ready = 0

        for y = Y1, Y2 do
            for x = X1, X2 do
                if safe(x, y) then
                    local s = w.seed_at(x, y)
                    if s and s.ready then
                        ready = ready + 1
                    end
                end
            end
        end

        if ready > 0 then
            sleep_ms(2000)
        else
            break
        end
    end
end

-------------------------------------------------
-- 4. HARVEST ALL
-------------------------------------------------

local function harvest_all()

    ensure()

    bot:set_auto_collect(true, 200)

    local w = bot:get_world()

    for y = Y1, Y2 do
        for x = X1, X2 do

            if safe(x, y) then
                local s = w.seed_at(x, y)

                if s and s.ready then
                    go(x, y)
                    sleep_ms(120)

                    bot:hit_block(0, 1)
                    sleep_ms(180)
                end
            end

        end
    end

    sleep_ms(800)
    bot:collectAll()
    sleep_ms(400)
    bot:set_auto_collect(false)
end

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------

while true do

    ensure()

    -- 1. BREAK FIRST
    break_all_blocks()

    -- 2. PLANT
    plant_all()

    -- 3. WAIT GROWTH
    wait_grow()

    -- 4. HARVEST
    harvest_all()

    sleep_ms(500)
end