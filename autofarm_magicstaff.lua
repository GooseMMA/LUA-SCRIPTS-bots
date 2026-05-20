-- ============================================================
-- ULTIMATE FARM v35.1: COMPACT DISCORD REPORT
-- Исправлена синтаксическая ошибка + компактный формат отчёта
-- ============================================================
math.randomseed(now_ms())

local CONFIG = {
    -- 🌐 НАСТРОЙКА ДИСКОРДА
    DISCORD_WEBHOOK   = "https://discord.com/api/webhooks/1480625069439979782/0j_I1U10sZ2AtOKmkV9RwPpKMRtDLKFbtfBRAR_TgyL_szEBFHDcwN9M2UBKTtlM1LbJ",
    TABLE_UPDATE_MS   = 120000, -- Отправка регулярного отчёта раз в 2 минуты

    WATER_ID          = 1344,
    STORAGE_WORLD     = "GOOSE",
    WORLD_PORTALS     = { "qwerty4", "qwerty2", "qwerty3" },
    
    DROP_SLOT_CAPACITY     = 20,
    DROP_FIRST_SLOT_STEPS  = 1,
    DROP_SLOT_STEP_SIZE    = 1,
    DROP_DISTRIBUTION_MODE = "fill",
    
    STORAGE_STEP_X    = 0,
    STORAGE_STEP_Y    = -1,
    
    WORLDS_BEFORE_DROP= 1,   
    MAX_STORAGE_BOTS  = 50,   
    
    HIT_DELAY_MS      = 250,
    MOVE_COOLDOWN_MS  = 350,
    PATH_TIMEOUT_MS   = 6000,
    COLLECT_WAIT_MS   = 300,
    WORLD_LOOP_LIMIT  = 0,
    STATUS_LOG_MS     = 30000,
    RECONNECT_CD_MS   = 5000, 
    MAX_PASSES        = 4,
    SYNC_WAIT_MS      = 600,  
    LIMBO_TIMEOUT_MS  = 45000,
    CONNECT_TIMEOUT_MS= 15000,
    TICK_DELAY_MS     = 35    
}

-- Глобальные счётчики
local bot_states = {}
local bot_status_msg = {}
local grand_found     = 0
local grand_broken    = 0
local grand_stored    = 0 
local total_cycles    = 0
local failed_cycles   = 0
local status_timer    = 0
local globalDropRouteSerial = 0
local global_storage_count = 0

local last_discord_update = 0     
local is_discord_sending = false  
local initial_report_sent = false 

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
        t[j], t[i] = t[i], t[j]
    end
    return t
end

local function getInvCount(bot, item_id)
    local inv = safeCall(bot.get_inventory, bot)
    if not inv then return 0 end
    local count = 0
    for _, item in ipairs(inv) do
        if item.id == item_id then
            count = count + (item.amount or 0)
        end
    end
    return count
end

-- ============================================================
-- 🛠️ ИСПРАВЛЕННАЯ ФУНКЦИЯ ОТПРАВКИ ВЕБХУКА
-- ============================================================
local function sendToWebhook(text)
    if CONFIG.DISCORD_WEBHOOK == "" or CONFIG.DISCORD_WEBHOOK:find("ТВОЙ_ВЕБХУК") then 
        log("[DISCORD] ❌ Ошибка: Вебхук пустой или не настроен.")
        return false
    end

    -- 🔪 Discord лимит: 2000 символов. Обрезаем с запасом.
    if #text > 1900 then
        text = text:sub(1, 1900) .. "\n...[cut]"
    end

    log("[DISCORD] 📦 Отправка: " .. #text .. " символов...")
    
    local response = http.post(CONFIG.DISCORD_WEBHOOK, { 
        json = { content = text },
        timeout = 10000,
        headers = { ["Content-Type"] = "application/json" }
    })
    
    if response == true then
        log("[DISCORD] ✅ Отправлено")
        return true
    elseif type(response) == "table" then
        if response.status == 204 or response.status == 200 then
            log("[DISCORD] ✅ HTTP " .. response.status)
            return true
        else
            log("[DISCORD] ❌ HTTP " .. tostring(response.status) .. " | " .. 
                (response.body or response.error or "нет данных"))
            return false
        end
    else
        log("[DISCORD] ⚠️ Ответ: " .. tostring(response))
        return false
    end
end

-- ============================================================
-- 📥 СТАРТОВЫЙ ОТЧЁТ (КОМПАКТНЫЙ)
-- ============================================================
local function sendInitialReport()
    local botIds = getBots()
    if #botIds == 0 then 
        log("[DISCORD] ⏳ Ожидание ботов...")
        return false 
    end
    
    local text = "```\n🚀 Ultimate Farm v35.1 ONLINE\n"
    text = text .. string.format("🤖 Ботов: %d | ⏰ %s\n", #botIds, os.date("%H:%M:%S"))
    text = text .. "─"..string.rep("─", 58).."─\n"
    
    for _, id in ipairs(botIds) do
        local b = getBot(id)
        local name = b and safeCall(b.get_username, b) or "Offline"
        if name == "" then name = "..." end
        local water = b and getInvCount(b, CONFIG.WATER_ID) or 0
        text = text .. string.format("▸ %s: 💧%d\n", name:sub(1,12), water)
    end
    text = text .. "```"
    
    sendToWebhook(text)
    return true
end

-- ============================================================
-- 📡 КОМПАКТНЫЙ ОТЧЁТ СТАТИСТИКИ (ВМЕСТИТСЯ В 2000 СИМВОЛОВ)
-- ============================================================
local function sendDiscordSpamReport()
    if is_discord_sending then return end
    is_discord_sending = true

    -- 📊 Компактный формат: ~800-1200 символов вместо 3000+
    local text = "```\n"
    text = text .. "🤖 Farm v35.1 | 💧"..grand_found.." 🔨"..grand_broken.." 🏦"..grand_stored
    text = text .. " | 🔄"..total_cycles.." | 🕒"..os.date("%H:%M").."```"
    text = text .. "```\n"
    text = text .. string.format("%-3s %-10s %-8s %-6s %-5s %-6s\n", "ID", "Bot", "💧Water", "World", "Done", "Avg")
    text = text .. string.rep("─", 45) .. "\n"

    local botIds = getBots()
    for _, id in ipairs(botIds) do
        local b = getBot(id)
        local st = bot_states[id]
        
        local name = "Offline"
        if b then
            name = safeCall(b.get_username, b) or "..."
            if name == "" then name = "..." end
        end
        if #name > 10 then name = name:sub(1, 8)..".." end
        
        local water = b and getInvCount(b, CONFIG.WATER_ID) or 0
        
        local world = "Menu"
        if b and st and safeCall(b.state, b) == "InWorld" then
            world = b:get_world_name() or "?"
            if #world > 8 then world = world:sub(1,6)..".." end
        elseif st and st.phase:find("storage") then
            world = "GOOSE"
        end
        
        local done = st and (st.worlds_cleared_count or 0) or 0
        local total = st and (st.worlds_done or 0) or 0
        
        local avg = "–"
        if st and st.total_cleared_worlds and st.total_cleared_worlds > 0 then
            local s = math.floor((st.total_clear_time_ms / st.total_cleared_worlds) / 1000)
            avg = s >= 60 and string.format("%dm", math.floor(s/60)) or string.format("%ds", s)
        end
        
        text = text .. string.format("%-3s %-10s %-8d %-8s %-5d %-6s\n", 
            id, name, water, world, done, avg)
    end
    text = text .. "```"

    sendToWebhook(text)
    is_discord_sending = false
end

local function allocateStorageRoute()
    globalDropRouteSerial = globalDropRouteSerial + 1
    local serial = globalDropRouteSerial
    local zeroIndex = serial - 1
    local portalCount = #CONFIG.WORLD_PORTALS
    local portalIndex, slotIndex = 1, 1

    if CONFIG.DROP_DISTRIBUTION_MODE == "round_robin" then
        portalIndex = (zeroIndex % portalCount) + 1
        local indexInsidePortal = math.floor(zeroIndex / portalCount)
        slotIndex = math.floor(indexInsidePortal / CONFIG.DROP_SLOT_CAPACITY) + 1
    else
        local fullSlotCapacity = CONFIG.DROP_SLOT_CAPACITY * portalCount
        local indexInsideFullSlot = zeroIndex % fullSlotCapacity
        slotIndex = math.floor(zeroIndex / fullSlotCapacity) + 1
        portalIndex = math.floor(indexInsideFullSlot / CONFIG.DROP_SLOT_CAPACITY) + 1
    end

    return {
        portal_id = CONFIG.WORLD_PORTALS[portalIndex] or "",
        steps = CONFIG.DROP_FIRST_SLOT_STEPS + ((slotIndex - 1) * CONFIG.DROP_SLOT_STEP_SIZE),
        slot = slotIndex
    }
end

local function init()
    for _, id in ipairs(getBots()) do
        bot_states[id] = {
            phase = "idle", worlds_done = 0, current_world = "",
            targets = {}, target_idx = 1, task = "move", hits_count = 0,
            next_action = 0, path_active = false, path_start = 0,
            last_reconnect = 0, pass = 0, is_refreshing = false,
            enter_time = 0, sync_retries = 0, last_heartbeat = 0, 
            connect_start = 0, worlds_cleared_count = 0, 
            storage_farm_world = "", storage_route = nil,
            storage_walk_step = 0, storage_walk_max = 0,
            drop_retries = 0, pending_drop_amount = 0,
            total_clear_time_ms = 0, total_cleared_worlds = 0
        }
        bot_status_msg[id] = "starting"
        local b = getBot(id)
        if b then pcall(b.set_auto_reconnect, b, false) end
    end
end
init()

local function heartbeat(st, id, msg)
    st.last_heartbeat = now_ms()
end

local function forceReconnect(b, st, id, reason)
    if st.phase:find("storage") and st.phase ~= "storage_return_wait" and st.phase ~= "storage_finish" then
        global_storage_count = math.max(0, global_storage_count - 1)
    end
    log("🔌 [", id, "] FORCE RECONNECT: ", reason)
    pcall(b.disconnect, b); pcall(b.connect, b)
    st.phase = "recover"; st.next_action = now_ms() + 3000
    st.last_reconnect = now_ms(); st.path_active = false; st.connect_start = 0
    st.enter_time = 0 
    heartbeat(st, id, "Force Reconnect")
end

log("🌍 Ultimate Farm v35.1 Started.")

last_discord_update = now_ms()

while true do
    local now = now_ms()
    
    collectgarbage("step", 50)

    if now - status_timer > CONFIG.STATUS_LOG_MS then status_timer = now end
    
    if not initial_report_sent then
        if sendInitialReport() then
            initial_report_sent = true
            log("[DISCORD] ✅ Стартовый отчёт отправлен.")
            last_discord_update = now
        end
    end

    if now - last_discord_update > CONFIG.TABLE_UPDATE_MS then
        log("[DISCORD] ⏰ Обновление таблицы...")
        last_discord_update = now
        sendDiscordSpamReport()
    end

    local botIds = getBots()
    shuffle(botIds)

    for _, id in ipairs(botIds) do
        local b = getBot(id)
        local st = bot_states[id]
        
        if b and not st then
            bot_states[id] = {
                phase = "idle", worlds_done = 0, current_world = "",
                targets = {}, target_idx = 1, task = "move", hits_count = 0,
                next_action = 0, path_active = false, path_start = 0,
                last_reconnect = 0, pass = 0, is_refreshing = false,
                enter_time = 0, sync_retries = 0, last_heartbeat = 0, 
                connect_start = 0, worlds_cleared_count = 0, 
                storage_farm_world = "", storage_route = nil,
                storage_walk_step = 0, storage_walk_max = 0,
                drop_retries = 0, pending_drop_amount = 0,
                total_clear_time_ms = 0, total_cleared_worlds = 0
            }
            st = bot_states[id]
            bot_status_msg[id] = "starting"
            pcall(b.set_auto_reconnect, b, false)
        end

        if not b or not st or st.phase == "done" or st.next_action > now then goto skip end

        local state = safeCall(b.state, b) or "Unknown"

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

        -- ================= ФАРМ ФАЗЫ =================
        if st.phase == "idle" and state == "MenuIdle" then
            local can_loop = CONFIG.WORLD_LOOP_LIMIT == 0 or st.worlds_done < CONFIG.WORLD_LOOP_LIMIT
            if can_loop then
                st.current_world = string.char(math.random(65,90))
                for _ = 3, math.random(8,15) do st.current_world = st.current_world .. string.char(math.random(65,90)) end
                pcall(b.send, b, "Gw", {eID = "", W = st.current_world, WB = 4})
                st.phase = "gw_sent"; st.next_action = now + 600 + math.random(5, 80) 
                bot_status_msg[id] = "creating"; heartbeat(st, id, "GW Sent")
            else st.phase = "done"; bot_status_msg[id] = "finished" end

        elseif st.phase == "gw_sent" then pcall(b.leave, b); st.phase = "wait_menu"; st.next_action = now + 800 + math.random(10, 100)
        elseif st.phase == "wait_menu" and state == "MenuIdle" then
            pcall(b.warp, b, st.current_world); st.phase = "entering"; st.next_action = now + 2500 + math.random(50, 200)
            bot_status_msg[id] = st.is_refreshing and "refreshing" or "entering"
        elseif st.phase == "entering" then
            if state == "InWorld" then 
                pcall(b.set_auto_collect, b, true, 100); 
                st.enter_time = now 
                st.sync_retries = 0
                st.phase = "syncing"; st.next_action = now + CONFIG.SYNC_WAIT_MS + math.random(10, 90)
                bot_status_msg[id] = "syncing"; heartbeat(st, id, "Entered")
            elseif now - st.next_action > 8000 then forceReconnect(b, st, id, "Enter timeout") end
        elseif st.phase == "syncing" then
            if isValidWorld(safeCall(b.get_world, b)) then st.phase = "scanning"; st.next_action = now; bot_status_msg[id] = "scanning"; heartbeat(st, id, "Synced")
            else st.next_action = now + 250 end
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
                else st.phase = "leaving"; st.next_action = now; bot_status_msg[id] = "leaving" end
            else
                local t = st.targets[st.target_idx]; local pos = safeCall(b.pos, b)
                local px, py = pos and pos.tile_x or 0, pos and pos.tile_y or 0
                local w = safeCall(b.get_world, b); local dist = pos and math.abs(px - t.x) + math.abs(py - t.y) or 999
                if not w or t.x < 0 or t.x >= w.width or t.y < 0 or t.y >= w.height then st.target_idx = st.target_idx + 1; st.task = "move"; st.hits_count = 0; st.next_action = now + 100
                else
                    if st.task == "move" then
                        if dist <= 2 then 
                            st.task = "hit"; st.hits_count = 0; st.path_active = false; 
                            st.next_action = now + CONFIG.HIT_DELAY_MS + math.random(-20, 50) 
                            heartbeat(st, id, "Arrived")
                        elseif not st.path_active then
                            if pcall(b.start_path, b, t.x, t.y) then st.path_active = true; st.path_start = now
                            else st.target_idx = st.target_idx + 1 end
                        else
                            if now - st.path_start > CONFIG.PATH_TIMEOUT_MS then st.path_active = false; st.target_idx = st.target_idx + 1
                            else st.next_action = now + CONFIG.MOVE_COOLDOWN_MS + math.random(-30, 40) end 
                        end
                    elseif st.task == "hit" then
                        if st.hits_count < 5 then 
                            pcall(b.send, b, "HW", {x=t.x, y=t.y, NGVj=0})
                            st.hits_count = st.hits_count + 1; 
                            st.next_action = now + CONFIG.HIT_DELAY_MS + math.random(-25, 45) 
                        else 
                            pcall(b.collectAll, b); grand_broken = grand_broken + 1; st.target_idx = st.target_idx + 1; st.task = "move"; st.hits_count = 0; pcall(b.collectAll, b); st.path_active = false; 
                            st.next_action = now + CONFIG.COLLECT_WAIT_MS + math.random(5, 60) 
                        end
                    end
                end
            end

        elseif st.phase == "refresh" then pcall(b.leave, b); st.phase = "wait_menu"; st.next_action = now + 1000 + math.random(0, 100)
        elseif st.phase == "leaving" then
            if state == "InWorld" then pcall(b.leave, b); st.next_action = now + 1200 + math.random(0, 100)
            else
                pcall(b.set_auto_collect, b, false); 
                st.worlds_done = st.worlds_done + 1; 
                total_cycles = total_cycles + 1
                st.worlds_cleared_count = (st.worlds_cleared_count or 0) + 1
                
                if st.enter_time and st.enter_time > 0 then
                    local session_time = now - st.enter_time
                    st.total_clear_time_ms = st.total_clear_time_ms + session_time
                    st.total_cleared_worlds = st.total_cleared_worlds + 1
                    st.enter_time = 0 
                end
                
                if st.worlds_cleared_count >= CONFIG.WORLDS_BEFORE_DROP then
                    log("💰 [", id, "] Время склада! (Миров: ", st.worlds_cleared_count, ")")
                    st.storage_farm_world = st.current_world; st.storage_route = allocateStorageRoute()
                    st.storage_walk_step = 0; st.storage_walk_max = st.storage_route.steps
                    st.phase = "storage_leave_farm"; st.next_action = now; st.queue_start_time = 0
                else 
                    st.phase = "idle"; st.pass = 0; st.is_refreshing = false; st.path_active = false; 
                    st.next_action = now + 300 + math.random(10, 150); bot_status_msg[id] = "idle"; heartbeat(st, id, "Cycle Done") 
                end
            end

        -- ============ ОЧЕРЕДЬ И СБРОС ============
        elseif st.phase == "storage_leave_farm" then 
            pcall(b.leave, b); st.phase = "storage_wait_menu"; st.next_action = now + 1000 + math.random(0, 100)
        elseif st.phase == "storage_wait_menu" then
            if state == "MenuIdle" then
                if global_storage_count < CONFIG.MAX_STORAGE_BOTS then
                    global_storage_count = global_storage_count + 1
                    local target = CONFIG.STORAGE_WORLD .. ":" .. st.storage_route.portal_id
                    log("🚀 [", id, "] Входим на склад: ", target, " (Слот ", global_storage_count, "/", CONFIG.MAX_STORAGE_BOTS, ")")
                    pcall(b.join_world, b, target)
                    st.phase = "storage_wait_join"; st.next_action = now + 3000 + math.random(0, 200)
                    bot_status_msg[id] = "storage_entering"
                else
                    if st.queue_start_time == 0 then st.queue_start_time = now end
                    if now - st.queue_start_time > 45000 then 
                        log("⚠️ [", id, "] Застрял в очереди. Перезагрузка.")
                        forceReconnect(b, st, id, "Queue stuck")
                    else
                        st.next_action = now + 350 
                        bot_status_msg[id] = "storage_queue"
                    end
                end
            elseif now - st.next_action > 10000 then st.phase = "recover" end
            
        elseif st.phase == "storage_wait_join" then
            if state == "InWorld" then 
                st.phase = "storage_move"; st.next_action = now + 250 + math.random(0, 50)
                bot_status_msg[id] = "storage_moving"
            elseif now - st.next_action > 4000 then 
                global_storage_count = math.max(0, global_storage_count - 1)
                st.phase = "storage_leave_farm"; st.next_action = now + 1000 
            end
            
        elseif st.phase == "storage_move" then
            if st.storage_walk_step < st.storage_walk_max then
                pcall(b.walk, b, CONFIG.STORAGE_STEP_X, CONFIG.STORAGE_STEP_Y)
                st.storage_walk_step = st.storage_walk_step + 1
                st.next_action = now + 130 + math.random(-15, 30) 
            else
                st.drop_retries = 0; st.pending_drop_amount = 0
                st.phase = "storage_drop"; st.next_action = now + 400 + math.random(10, 100) 
                bot_status_msg[id] = "storage_dropping"
            end
            
        elseif st.phase == "storage_drop" then
            local inv = safeCall(b.get_inventory, b)
            local target_item = nil
            
            if inv then
                for _, item in ipairs(inv) do
                    if item.id == CONFIG.WATER_ID and item.amount > 0 then
                        target_item = item; break
                    end
                end
            end

            if target_item then
                st.drop_retries = (st.drop_retries or 0) + 1
                
                if st.drop_retries > 6 then
                    st.drop_retries = 0; st.phase = "storage_leave_goose"; st.next_action = now + 300
                else
                    st.pending_drop_amount = target_item.amount 
                    local inv_type = target_item.inventory_type or 0
                    pcall(b.drop, b, target_item.id, target_item.amount, inv_type)
                    st.next_action = now + 600 + math.random(10, 150) 
                end
            else
                if st.pending_drop_amount > 0 then
                    grand_stored = grand_stored + st.pending_drop_amount
                    st.pending_drop_amount = 0
                end
                st.drop_retries = 0; st.phase = "storage_leave_goose"; st.next_action = now + 250 + math.random(5, 50)
            end
            
        elseif st.phase == "storage_leave_goose" then 
            pcall(b.leave, b)
            global_storage_count = math.max(0, global_storage_count - 1)
            st.phase = "storage_return_wait"; st.next_action = now + 1200 + math.random(0, 100)
            bot_status_msg[id] = "storage_returning"
            
        elseif st.phase == "storage_return_wait" then
            if state == "MenuIdle" then
                pcall(b.warp, b, st.storage_farm_world)
                st.phase = "storage_finish"; st.next_action = now + 3000 + math.random(0, 200)
            elseif now - st.next_action > 8000 then st.phase = "recover" end
            
        elseif st.phase == "storage_finish" then
            if state == "InWorld" then
                pcall(b.set_auto_collect, b, true, 100); st.worlds_cleared_count = 0
                st.phase = "syncing"; st.next_action = now + 600 + math.random(0, 100)
                bot_status_msg[id] = "farming"
            elseif now - st.next_action > 3000 then st.phase = "storage_leave_farm"; st.next_action = now + 1000 end

        -- ВОССТАНОВЛЕНИЕ
        elseif st.phase == "recover" then
            if not b:connected() then pcall(b.connect, b); st.next_action = now + 2000; st.connect_start = now
            elseif state == "MenuIdle" and st.current_world ~= "" then
                pcall(b.warp, b, st.current_world); st.phase = "entering"; st.next_action = now + 2500; heartbeat(st, id, "Recovered")
            elseif state == "InWorld" then st.phase = "syncing"; st.next_action = now; heartbeat(st, id, "Recovered InWorld")
            else st.next_action = now + 500 end
        end

        ::skip::
    end
    sleep_ms(CONFIG.TICK_DELAY_MS)
end
