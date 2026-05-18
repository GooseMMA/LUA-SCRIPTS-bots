local bot = getBot(SLOT_ID)
if not bot then return end

-------------------------------------------------
-- ⚙️ КОНФИГУРАЦИЯ (НАСТРОЙКИ)
-------------------------------------------------
local PORTAL_FARM   = "TEST02:ferma1"   -- Портал на ферму
local PORTAL_BREAK  = "TEST02:farm1"    -- Портал на площадку инста-брейка
local PORTAL_DROP   = "TEST02:qwerty3"  -- Портал для сброса излишков семян

-- 💎 ПАРАМЕТРЫ ПРЕДМЕТА И ПЛАНТАЦИИ
local TARGET_ID      = 2735             -- ID Gem Soil
local HITS_PER_BLOCK = 4                -- Удары

local FARM_Y         = 3                -- Линия грядки
local FARM_X1, FARM_X2 = 0, 79          -- Границы фермы

-- 📦 ЛИМИТЫ СЕМЯН
local SEED_LIMIT    = 600               -- Порог сброса
local SEED_KEEP     = 400               -- Сколько оставить себе

-------------------------------------------------
-- 💾 СИСТЕМА ИНВЕНТАРЯ
-------------------------------------------------
local _local_state = { phase = "plant" }
local safe_storage = {
    set = function(k, v)
        if storage and storage.set then pcall(storage.set, k, v) end
        _local_state[k] = v
    end,
    get = function(k)
        if storage and storage.get then 
            local ok, res = pcall(storage.get, k)
            if ok and res then return res end
        end
        return _local_state[k]
    end
}

local function count_items(type_id)
    local items = bot:get_inventory()
    if not items then return 0 end
    local count = 0
    for _, item in ipairs(items) do
        if item.id == TARGET_ID and item.inventory_type == type_id then 
            count = count + item.amount 
        end
    end
    return count
end

-------------------------------------------------
-- 🌀 НАВИГАЦИЯ
-------------------------------------------------
local function smart_warp(portal_id)
    local target_world_clean = portal_id:match("^([^:]+)")
    while true do
        local state = bot:state()
        if state == "InWorld" then
            local current_world = bot:get_world_name()
            if current_world and current_world:upper() == target_world_clean:upper() then
                sleep_ms(800) -- Даем чуть больше времени на прогрузку координат
                return true 
            else
                log(string.format("🌍 Переход из чужого мира в %s", portal_id))
                pcall(function() bot:warp(portal_id) end)
                sleep_ms(3500)
            end
        elseif state == "MenuIdle" then
            log("📺 Отправляем варп на " .. portal_id)
            pcall(function() bot:warp(portal_id) end)
            sleep_ms(4000)
        elseif state == "Connecting" then
            sleep_ms(500)
        else
            log("🔌 Переподключение...")
            pcall(function() bot:connect() end)
            sleep_ms(3000)
        end
    end
end

local function smart_move_to(target_x, target_y)
    if pcall(function() bot:find_path(target_x, target_y) end) then return true end
    local fallbacks = { target_y + 1, target_y - 1 }
    for _, alt_y in ipairs(fallbacks) do
        if pcall(function() bot:find_path(target_x, alt_y) end) then return true end
    end
    return false
end

local function fast_collect_moves()
    local moves = {{0,-1}, {0,1}, {1,0}, {-1,0}, {-1,0}}
    for _, m in ipairs(moves) do
        pcall(function() bot:walk(m[1], m[2]) end)
        sleep_ms(60)
        pcall(function() bot:collectAll() end)
        sleep_ms(20)
    end
end

-------------------------------------------------
-- 🛠️ ФАЗЫ ЦИКЛА
-------------------------------------------------

-- 1. ПОСАДКА
local function phase_plant()
    log("🌱 Начинаем фазу посадки...")
    
    if count_items(2) == 0 then
        if count_items(0) > 0 then
            log("⚠️ Семян 0, но есть блоки. Идем ломать!")
            safe_storage.set("phase", "break")
            return
        else
            log("⚠️ Семян 0 и блоков 0. Ждем созревания того, что успели посадить.")
            safe_storage.set("phase", "wait")
            return
        end
    end

    smart_warp(PORTAL_FARM)
    
    for x = FARM_X1, FARM_X2 do
        if bot:state() ~= "InWorld" then smart_warp(PORTAL_FARM) end
        
        if count_items(2) == 0 then
            if count_items(0) > 0 then
                log("⚠️ Семена закончились посреди грядки. Идем ломать блоки.")
                safe_storage.set("phase", "break")
            else
                log("⚠️ Семена и блоки на нуле. Переходим к ожиданию урожая.")
                safe_storage.set("phase", "wait")
            end
            return
        end
        
        local w = bot:get_world()
        if w and w.fg_at(x, FARM_Y) == 0 then
            if smart_move_to(x, FARM_Y) then
                sleep_ms(50)
                while bot:get_world() and bot:get_world().fg_at(x, FARM_Y) ~= 0 do
                    pcall(function() bot:hit(x, FARM_Y) end)
                    sleep_ms(150)
                end
                pcall(function() bot:plant(x, FARM_Y, TARGET_ID) end)
                sleep_ms(80)
            end
        end
    end
    safe_storage.set("phase", "wait")
end

-- 2. ОЖИДАНИЕ
local function phase_wait()
    log("⏳ Ожидание созревания деревьев...")
    smart_warp(PORTAL_FARM)
    
    while true do
        if bot:state() ~= "InWorld" then smart_warp(PORTAL_FARM) end
        
        local seeds = bot:seeds()
        local total_tracked = 0
        local ready_tracked = 0
        
        for _, s in ipairs(seeds) do
            if s.y == FARM_Y and s.x >= FARM_X1 and s.x <= FARM_X2 then
                total_tracked = total_tracked + 1
                if s.ready then ready_tracked = ready_tracked + 1 end
            end
        end
        
        log(string.format("🌿 Созревание плантации: %d/%d", ready_tracked, total_tracked))
        
        if total_tracked > 0 and ready_tracked >= total_tracked then
            break
        elseif total_tracked == 0 then
            if count_items(2) == 0 and count_items(0) == 0 then
                log("💀 ПОЛНОЕ БАНКРОТСТВО: Семян нет, блоков нет, грядка пуста. Остановка бота.")
                while true do sleep_ms(60000) end 
            else
                log("❌ Грядка пуста. Возврат к посадке.")
                safe_storage.set("phase", "plant")
                return
            end
        end
        sleep_ms(5000)
    end
    safe_storage.set("phase", "harvest")
end

-- 3. СБОР УРОЖАЯ
local function phase_harvest()
    log("🪓 Сбор урожая...")
    smart_warp(PORTAL_FARM)
    
    for x = FARM_X1, FARM_X2 do
        if bot:state() ~= "InWorld" then smart_warp(PORTAL_FARM) end
        if smart_move_to(x, FARM_Y) then
            sleep_ms(50)
            local w = bot:get_world()
            while w and w.fg_at(x, FARM_Y) ~= 0 do
                pcall(function() bot:hit(x, FARM_Y) end)
                sleep_ms(140) 
                w = bot:get_world() 
            end
            pcall(function() bot:collectAll() end)
        end
    end
    safe_storage.set("phase", "collect")
end

-- 4. СБОР ЛУТА
local function phase_collect()
    log("🧲 Сбор лута...")
    smart_warp(PORTAL_FARM)
    
    for x = FARM_X1, FARM_X2 do
        if bot:state() ~= "InWorld" then smart_warp(PORTAL_FARM) end
        pcall(function() bot:collect_at(x, FARM_Y) end)
        pcall(function() bot:collect_at(x, FARM_Y + 1) end)
        pcall(function() bot:collect_at(x, FARM_Y - 1) end)
        sleep_ms(20)
    end
    
    fast_collect_moves()
    safe_storage.set("phase", "break")
end

-- 5. ИНСТА-БРЕЙК БЛОКОВ
local function phase_break()
    log("⚡ Фаза инста-брейка блоков ID: " .. TARGET_ID)
    
    while true do
        local blocks_count = count_items(0)
        log("📦 Блоков в инвентаре осталось разрушить: " .. blocks_count)
        
        if blocks_count <= 0 then 
            log("✅ Все блоки из инвентаря успешно разбиты в крошку.")
            break 
        end
        
        smart_warp(PORTAL_BREAK)
        
        local pos = bot:pos()
        if pos then
            local px, py = pos.tile_x, pos.tile_y
            
            -- 🔥 ЦЕЛЕВАЯ ЗОНА: 3 блока В РЯД НАД ГОЛОВОЙ (чтобы не задеть портал и пол)
            -- py это ноги, py-1 это голова, py-2 это блок над головой
            local targets = { {px - 1, py - 2}, {px, py - 2}, {px + 1, py - 2} }
            
            for _, t in ipairs(targets) do
                -- Юзер просил 30 блоков в каждую точку (итого 90 за цикл)
                for i = 1, 30 do
                    -- Оптимизация: если блоки кончились посреди цикла - прерываем спам
                    if blocks_count <= 0 then break end
                    
                    bot:send("SB", {x = t[1], y = t[2], BlockType = TARGET_ID}) 
                    local packet_hits = HITS_PER_BLOCK + 2 
                    for j = 1, packet_hits do 
                        bot:send("HB", {x = t[1], y = t[2]}) 
                    end
                    
                    blocks_count = blocks_count - 1
                end
            end
            
            sleep_ms(150) 
            pcall(function() bot:leave() end) 
            sleep_ms(400) 
            
            smart_warp(PORTAL_BREAK)
            sleep_ms(800) 
            fast_collect_moves()
        end
    end
    safe_storage.set("phase", "drop")
end

-- 6. СБРОС ИЗЛИШКОВ
local function phase_drop()
    local current_seeds = count_items(2)
    log("📦 Всего семян в сумке: " .. current_seeds)
    
    if current_seeds > SEED_LIMIT then
        local drop_amount = current_seeds - SEED_KEEP
        log(string.format("📉 Скидываем избыток семян: %d шт.", drop_amount))
        
        smart_warp(PORTAL_DROP)
        sleep_ms(1000)
        pcall(function() bot:drop(TARGET_ID, drop_amount, 2) end)
        sleep_ms(1500)
    else
        log("✅ Семена в норме. Пропускаем сброс.")
    end
    safe_storage.set("phase", "plant")
end

-------------------------------------------------
-- 🔄 ГЛАВНЫЙ ЦИКЛ БОТА
-------------------------------------------------
runThread(function()
    log("🚀 Фарм-машина v5.9 УСПЕШНО ЗАПУЩЕНА! (Бережем порталы!)")
    while true do
        local current_phase = safe_storage.get("phase") or "plant"
        
        if current_phase == "plant" then phase_plant()
        elseif current_phase == "wait" then phase_wait()
        elseif current_phase == "harvest" then phase_harvest()
        elseif current_phase == "collect" then phase_collect()
        elseif current_phase == "break" then phase_break()
        elseif current_phase == "drop" then phase_drop()
        else safe_storage.set("phase", "plant") end
        
        sleep_ms(500)
    end
end)

while true do sleep_ms(1000) end
