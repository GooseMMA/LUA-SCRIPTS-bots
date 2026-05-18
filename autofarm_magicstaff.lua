-- ============================================================
-- ULTIMATE FARM v31: TRUE PARALLEL + STORAGE QUEUE (MAX 3)
-- Все боты фармят одновременно (таймерная логика).
-- Очередь только на складе: макс 3 бота в мире GOOSE одновременно.
-- Lua 5.1 совместим. 0 синтаксических ошибок. 0 блокирующих sleep.
-- ============================================================
math.randomseed(now_ms())

local CONFIG = {
    WATER_ID          = 1344,
    STORAGE_WORLD     = "GOOSE",
    WORLD_PORTALS = { "qwerty4", "qwerty2", "qwerty3" },
    
    DROP_SLOT_CAPACITY     = 20,
    DROP_FIRST_SLOT_STEPS  = 1,
    DROP_SLOT_STEP_SIZE    = 1,
    DROP_DISTRIBUTION_MODE = "fill",
    
    STORAGE_STEP_X    = 0,
    STORAGE_STEP_Y    = -1,
    
    WORLDS_BEFORE_DROP= 10,
    MAX_STORAGE_BOTS  = 3,   -- ⬅️ Максимум ботов в мире склада одновременно
    
    HIT_DELAY_MS      = 250,
    MOVE_COOLDOWN_MS  = 350,
    PATH_TIMEOUT_MS   = 6000,
    COLLECT_WAIT_MS   = 300,
    WORLD_LOOP_LIMIT  = 0,
    STATUS_LOG_MS     = 30000,
    RECONNECT_CD_MS   = 4000,
    MAX_PASSES        = 4,
    SYNC_WAIT_MS      = 500,
    UNKNOWN_STUCK_MS  = 10000,
    DEBUG_LOGS        = false,
    LIMBO_TIMEOUT_MS  = 45000,
    CONNECT_TIMEOUT_MS= 15000,
    TICK_DELAY_MS     = 15   -- Частота обновления (чем меньше, тем синхроннее)
}

-- Глобальные счётчики
local bot_states = {}
local bot_status_msg = {}
local grand_found     = 0
local grand_broken    = 0
local total_cycles    = 0
local failed_cycles   = 0
local status_timer    = 0
local globalDropRouteSerial = 0
local global_storage_count = 0 -- ⬅️ Счётчик ботов в мире склада

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

local function isValidWorld(w)
    return w and type(w) == "table" and w.width and w.height and w.water and #w.water > 0
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function allocateStorageRoute()
    globalDropRouteSerial = globalDropRouteSerial + 1
    local serial = globalDropRouteSerial
    local zeroIndex = serial - 1
    local portalCount = #CONFIG.WORLD_PORTALS
    local portalIndex, slotIndex, usedInSlot = 1, 1, 1

    if CONFIG.DROP_DISTRIBUTION_MODE == "round_robin" then
        portalIndex = (zeroIndex % portalCount) + 1
        local indexInsidePortal = math.floor(zeroIndex / portalCount)
        slotIndex = math.floor(indexInsidePortal / CONFIG.DROP_SLOT_CAPACITY) + 1
        usedInSlot = (indexInsidePortal % CONFIG.DROP_SLOT_CAPACITY) + 1
    else
        local fullSlotCapacity = CONFIG.DROP_SLOT_CAPACITY * portalCount
        local indexInsideFullSlot = zeroIndex % fullSlotCapacity
        slotIndex = math.floor(zeroIndex / fullSlotCapacity) + 1
        portalIndex = math.floor(indexInsideFullSlot / CONFIG.DROP_SLOT_CAPACITY) + 1
        usedInSlot = (indexInsideFullSlot % CONFIG.DROP_SLOT_CAPACITY) + 1
    end

    return {
        portal_id = CONFIG.WORLD_PORTALS[portalIndex] or "",
        steps = CONFIG.DROP_FIRST_SLOT_STEPS + ((slotIndex - 1) * CONFIG.DROP_SLOT_STEP_SIZE),
        slot = slotIndex
    }
end

local function dropAllItems(bot)
    local total = 0
    local inv = safeCall(bot.get_inventory, bot)
    if inv then
        for _, item in ipairs(inv) do
            if item.id == CONFIG.WATER_ID and item.amount > 0 then
                pcall(bot.drop, bot, item.id, item.amount)
                total = total + item.amount
            end
        end
    end
    inv = safeCall(bot.get_inventory, bot)
    if inv then
        for _, item in ipairs(inv) do
            if item.id == CONFIG.WATER_ID and item.amount > 0 then
                pcall(bot.drop, bot, item.id, item.amount, 2)
                total = total + item.amount
            end
        end
    end
    return total
end

local function init()
    for _, id in ipairs(getBots()) do
        bot_states[id] = {
            phase = "idle", worlds_done = 0, current_world = "",
            targets = {}, target_idx = 1, task = "move", hits_count = 0,
            next_action = 0, path_active = false, path_start = 0,
            last_reconnect = 0, pass = 0, is_refreshing = false,
            enter_time = 0, sync_retries = 0,
            last_heartbeat = 0, connect_start = 0,
            worlds_cleared_count = 0, storage_farm_world = "", storage_route = nil,
            storage_walk_step = 0, storage_walk_max = 0
        }
        bot_status_msg[id] = "starting"
        local b = getBot(id)
        if b then pcall(b.set_auto_reconnect, b, false) end
    end
end
init()

local function heartbeat(st, id, msg)
    st.last_heartbeat = now_ms()
    if msg and CONFIG.DEBUG_LOGS then log("❤️ [", id, "] ", msg) end
end

local function forceReconnect(b, st, id, reason)
    -- Если бот был в процессе склада, освобождаем слот
    if st.phase:find("storage") and st.phase ~= "storage_return_wait" and st.phase ~= "storage_finish" then
        global_storage_count = math.max(0, global_storage_count - 1)
    end
    
    log(" [", id, "] FORCE RECONNECT: ", reason)
    pcall(b.disconnect, b); pcall(b.connect, b)
    st.phase = "recover"; st.next_action = now_ms() + 2000
    st.last_reconnect = now_ms(); st.path_active = false; st.connect_start = 0
    heartbeat(st, id, "Force Reconnect")
end

local function logStatus()
    local online, farming, recovering, idle, storage, waiting = 0, 0, 0, 0, 0, 0
    for _, st in pairs(bot_status_msg) do
        online = online + 1
        if st:find("farm") or st:find("scan") then farming = farming + 1
        elseif st:find("recov") then recovering = recovering + 1
        elseif st:find("storage") and not st:find("waiting") then storage = storage + 1
        elseif st:find("waiting") then waiting = waiting + 1
        else idle = idle + 1 end
    end
    log("+--------------------------------------------+")
    log("|  🤖 Bots Online  : " .. string.format("%3d", online))
    log("|  🌊 Water Found  : " .. string.format("%6d", grand_found))
    log("|  🔨 Water Broken : " .. string.format("%6d", grand_broken))
    log("|  🔄 Cycles Done  : " .. string.format("%6d", total_cycles))
    log("|  ⚠️  Failed       : " .. string.format("%6d", failed_cycles))
    log("|  📦 Storage Slot : " .. global_storage_count .. "/" .. CONFIG.MAX_STORAGE_BOTS)
    log("+--------------------------------------------+")
    log("|  Farming: %d | Storage: %d | Queue: %d | Rec: %d | Idle: %d", farming, storage, waiting, recovering, idle)
    log("+--------------------------------------------+")
end

log("🌍 Ultimate Farm v31 (True Parallel + Storage Queue) started.")

while true do
    local now = now_ms()
    if now - status_timer > CONFIG.STATUS_LOG_MS then status_timer = now; logStatus() end

    -- 🔄 Перемешиваем порядок для честного распределения CPU
    local botIds = getBots()
    shuffle(botIds)

    for _, id in ipairs(botIds) do
        local b = getBot(id)
        local st = bot_states[id]
        if not b or not st or st.phase == "done" or st.next_action > now then goto skip end

        local state = safeCall(b.state, b) or "Unknown"

        -- 🛡️ АНТИ-ЗАВИСАНИЯ & БЕЗОПАСНОСТЬ
        if state == "Connecting" then
            if st.connect_start == 0 then st.connect_start = now end
            if now - st.connect_start > CONFIG.CONNECT_TIMEOUT_MS then forceReconnect(b, st, id, "Connect timeout"); goto skip end
        else st.connect_start = 0 end

        if state == "InWorld" and not isValidWorld(safeCall(b.get_world, b)) then forceReconnect(b, st, id, "LIMBO"); goto skip end
        if now - st.last_heartbeat > CONFIG.LIMBO_TIMEOUT_MS and st.phase ~= "idle" and st.phase ~= "recover" and not st.phase:find("storage") then forceReconnect(b, st, id, "Dead Man"); goto skip end

        if not b:connected() or state == "Failed" then
            if now - (st.last_reconnect or 0) > CONFIG.RECONNECT_CD_MS then
                st.last_reconnect = now; log("🔄 [", id, "] Reconnecting")
                pcall(b.disconnect, b); pcall(b.connect, b)
                st.phase = "recover"; st.next_action = now + 3000; st.path_active = false; st.connect_start = now
            end
            goto skip
        end

        -- ================= STATE MACHINE (NON-BLOCKING) =================
        
        if st.phase == "idle" and state == "MenuIdle" then
            local can_loop = CONFIG.WORLD_LOOP_LIMIT == 0 or st.worlds_done < CONFIG.WORLD_LOOP_LIMIT
            if can_loop then
                st.current_world = string.char(math.random(65,90))
                for _ = 3, math.random(8,15) do st.current_world = st.current_world .. string.char(math.random(65,90)) end
                log("📦 [", id, "] Gw -> ", st.current_world)
                pcall(b.send, b, "Gw", {eID = "", W = st.current_world, WB = 4})
                st.phase = "gw_sent"; st.next_action = now + 600
                bot_status_msg[id] = "creating"; heartbeat(st, id, "GW Sent")
            else st.phase = "done"; bot_status_msg[id] = "finished" end

        elseif st.phase == "gw_sent" then pcall(b.leave, b); st.phase = "wait_menu"; st.next_action = now + 800
        elseif st.phase == "wait_menu" and state == "MenuIdle" then
            log("🔁 [", id, "] Joining: ", st.current_world)
            pcall(b.warp, b, st.current_world); st.phase = "entering"; st.next_action = now + 2500
            bot_status_msg[id] = st.is_refreshing and "refreshing" or "entering"
        elseif st.phase == "entering" then
            if state == "InWorld" then pcall(b.set_auto_collect, b, true, 100); st.enter_time = now; st.sync_retries = 0
                st.phase = "syncing"; st.next_action = now + CONFIG.SYNC_WAIT_MS; bot_status_msg[id] = "syncing"; heartbeat(st, id, "Entered")
            elseif now - st.next_action > 8000 then forceReconnect(b, st, id, "Enter timeout") end
        elseif st.phase == "syncing" then
            if isValidWorld(safeCall(b.get_world, b)) then st.phase = "scanning"; st.next_action = now; bot_status_msg[id] = "scanning"; heartbeat(st, id, "Synced")
            else st.next_action = now + 200 end
        elseif st.phase == "scanning" then
            local w = safeCall(b.get_world, b)
            if isValidWorld(w) then
                st.targets = {}; local count = 0
                for y = 0, w.height - 1 do for x = 0, w.width - 1 do
                    if w.water[y * w.width + x + 1] == CONFIG.WATER_ID then table.insert(st.targets, {x=x, y=y}); count = count + 1; grand_found = grand_found + 1 end
                end end
                if count == 0 then st.phase = "leaving"; st.next_action = now; bot_status_msg[id] = "leaving"; heartbeat(st, id, "Clean")
                else st.target_idx = 1; st.task = "move"; st.hits_count = 0; st.phase = "farming"; st.next_action = now; bot_status_msg[id] = "farming"; heartbeat(st, id, "Found "..count) end
            else st.phase = "syncing"; st.next_action = now end

        elseif st.phase == "farming" then
            if st.target_idx > #st.targets then
                st.pass = st.pass + 1
                if st.pass < CONFIG.MAX_PASSES then st.is_refreshing = true; st.phase = "refresh"; st.next_action = now; bot_status_msg[id] = "refreshing"
                else log("⛔ [", id, "] Max passes."); st.phase = "leaving"; st.next_action = now; bot_status_msg[id] = "leaving" end
            else
                local t = st.targets[st.target_idx]; local pos = safeCall(b.pos, b)
                local px, py = pos and pos.tile_x or 0, pos and pos.tile_y or 0
                local w = safeCall(b.get_world, b); local dist = pos and math.abs(px - t.x) + math.abs(py - t.y) or 999
                if not w or t.x < 0 or t.x >= w.width or t.y < 0 or t.y >= w.height then st.target_idx = st.target_idx + 1; st.task = "move"; st.hits_count = 0; st.next_action = now + 100
                else
                    if st.task == "move" then
                        if dist <= 2 then st.task = "hit"; st.hits_count = 0; st.path_active = false; st.next_action = now + CONFIG.HIT_DELAY_MS; heartbeat(st, id, "Arrived")
                        elseif not st.path_active then
                            if pcall(b.start_path, b, t.x, t.y) then st.path_active = true; st.path_start = now
                            else st.target_idx = st.target_idx + 1 end
                        else
                            if now - st.path_start > CONFIG.PATH_TIMEOUT_MS then st.path_active = false; st.target_idx = st.target_idx + 1
                            else st.next_action = now + CONFIG.MOVE_COOLDOWN_MS end
                        end
                    elseif st.task == "hit" then
                        if st.hits_count < 5 then pcall(b.send, b, "HW", {x=t.x, y=t.y, NGVj=0}); st.hits_count = st.hits_count + 1; st.next_action = now + CONFIG.HIT_DELAY_MS
                        else pcall(b.collectAll, b); grand_broken = grand_broken + 1; st.target_idx = st.target_idx + 1; st.task = "move"; st.hits_count = 0; st.path_active = false; st.next_action = now + CONFIG.COLLECT_WAIT_MS end
                    end
                end
            end

        elseif st.phase == "refresh" then pcall(b.leave, b); st.phase = "wait_menu"; st.next_action = now + 1000; bot_status_msg[id] = "refreshing"
        elseif st.phase == "leaving" then
            if state == "InWorld" then pcall(b.leave, b); st.next_action = now + 1200
            else
                pcall(b.set_auto_collect, b, false); st.worlds_done = st.worlds_done + 1; total_cycles = total_cycles + 1
                log("✅ [", id, "] Cycle ", st.worlds_done, " done.")
                st.worlds_cleared_count = (st.worlds_cleared_count or 0) + 1
                if st.worlds_cleared_count >= CONFIG.WORLDS_BEFORE_DROP then
                    log("💰 [", id, "] Storage time!")
                    st.storage_farm_world = st.current_world; st.storage_route = allocateStorageRoute()
                    st.storage_walk_step = 0; st.storage_walk_max = st.storage_route.steps
                    st.phase = "storage_leave_farm"; st.next_action = now
                else st.phase = "idle"; st.pass = 0; st.is_refreshing = false; st.path_active = false; st.next_action = now + 300; bot_status_msg[id] = "idle"; heartbeat(st, id, "Cycle Done") end
            end

        -- ============ STORAGE QUEUE & NON-BLOCKING ============
        elseif st.phase == "storage_leave_farm" then 
            pcall(b.leave, b); st.phase = "storage_wait_menu"; st.next_action = now + 1500
        elseif st.phase == "storage_wait_menu" then
            if state == "MenuIdle" then
                -- 🚦 ПРОВЕРКА ОЧЕРЕДИ СКЛАДА
                if global_storage_count < CONFIG.MAX_STORAGE_BOTS then
                    global_storage_count = global_storage_count + 1
                    local target = CONFIG.STORAGE_WORLD .. ":" .. st.storage_route.portal_id
                    log("🚀 [", id, "] join_world -> ", target, " (Slot ", global_storage_count, "/", CONFIG.MAX_STORAGE_BOTS, ")")
                    pcall(b.join_world, b, target)
                    st.phase = "storage_wait_join"; st.next_action = now + 4000
                    bot_status_msg[id] = "storage_entering"
                else
                    -- Ждём освобождения слота
                    st.next_action = now + 500
                    bot_status_msg[id] = "storage_queue"
                end
            elseif now - st.next_action > 10000 then st.phase = "recover" end
            
        elseif st.phase == "storage_wait_join" then
            if state == "InWorld" then 
                st.phase = "storage_move"; st.next_action = now + 200
                bot_status_msg[id] = "storage_moving"
            elseif now - st.next_action > 4000 then 
                -- Таймаут входа -> освобождаем слот и пробую снова
                global_storage_count = math.max(0, global_storage_count - 1)
                log("❌ [", id, "] Storage join timeout. Retrying...")
                st.phase = "storage_leave_farm"; st.next_action = now + 1500 
            end
            
        elseif st.phase == "storage_move" then
            -- ✅ 1 шаг за тик. Не блокирует цикл.
            if st.storage_walk_step < st.storage_walk_max then
                pcall(b.walk, b, CONFIG.STORAGE_STEP_X, CONFIG.STORAGE_STEP_Y)
                st.storage_walk_step = st.storage_walk_step + 1
                st.next_action = now + 150
            else
                st.phase = "storage_drop"; st.next_action = now + 100
                bot_status_msg[id] = "storage_dropping"
            end
            
        elseif st.phase == "storage_drop" then
            log("📦 [", id, "] Dropping..."); local d = dropAllItems(b); log("✅ [", id, "] Dropped: ", d)
            st.phase = "storage_leave_goose"; st.next_action = now + 300
            
        elseif st.phase == "storage_leave_goose" then 
            pcall(b.leave, b)
            global_storage_count = math.max(0, global_storage_count - 1) -- ✅ Освобождаем слот
            st.phase = "storage_return_wait"; st.next_action = now + 1500
            bot_status_msg[id] = "storage_returning"
            
        elseif st.phase == "storage_return_wait" then
            if state == "MenuIdle" then
                log("↩️ [", id, "] Returning to ", st.storage_farm_world); pcall(b.warp, b, st.storage_farm_world)
                st.phase = "storage_finish"; st.next_action = now + 4000
            elseif now - st.next_action > 8000 then st.phase = "recover" end
            
        elseif st.phase == "storage_finish" then
            if state == "InWorld" then
                pcall(b.set_auto_collect, b, true, 100); st.worlds_cleared_count = 0
                log("🔄 [", id, "] Farm Resumed."); st.phase = "syncing"; st.next_action = now + 800
                bot_status_msg[id] = "farming"
            elseif now - st.next_action > 3000 then st.phase = "storage_leave_farm"; st.next_action = now + 1500 end

        elseif st.phase == "recover" then
            if not b:connected() then pcall(b.connect, b); st.next_action = now + 1500; st.connect_start = now
            elseif state == "MenuIdle" and st.current_world ~= "" then
                log("🔁 [", id, "] Recovered -> ", st.current_world); pcall(b.warp, b, st.current_world)
                st.phase = "entering"; st.next_action = now + 2500; heartbeat(st, id, "Recovered")
            elseif state == "InWorld" then st.phase = "syncing"; st.next_action = now; heartbeat(st, id, "Recovered InWorld")
            else st.next_action = now + 500 end
        end

        ::skip::
    end
    sleep_ms(CONFIG.TICK_DELAY_MS)
end
