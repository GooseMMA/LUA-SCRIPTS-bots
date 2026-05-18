local bot = getBot(SLOT_ID)
if not bot then return end

-------------------------------------------------
-- ⚙️ КОНФИГУРАЦИЯ (НАСТРОЙКИ)
-------------------------------------------------
local PORTAL_FARM   = "TEST02:ferma1"   -- Портал на ферму
local PORTAL_BREAK  = "TEST02:farm1"    -- Портал на площадку инста-брейка
local PORTAL_DROP   = "TEST02:qwerty3"  -- Портал для сброса излишков семян

local FARM_WORLD_NAME  = "FARM_WORLD"   
local BREAK_WORLD_NAME = "BREAK_WORLD"  
local DROP_WORLD_NAME  = "GOOSE"        

-- 💎 ПАРАМЕТРЫ ПРЕДМЕТА И ПЛАНТАЦИИ
local TARGET_ID      = 2735             -- ID Gem Soil (и для блока, и для семени)
local HITS_PER_BLOCK = 4                -- Сколько ударов нужно для разрушения Gem Soil

local FARM_Y         = 3                -- Линия грядки
local FARM_X1, FARM_X2 = 0, 79          -- Границы фермы по горизонтали

-- 📦 ЛИМИТЫ СЕМЯН В ИНВЕНТАРЕ
local SEED_LIMIT    = 600               -- Порог, выше которого идем скидывать семена
local SEED_KEEP     = 400               -- Сколько семян бот оставляет себе для работы

-------------------------------------------------
-- 💾 STORAGE & СЧЕТЧИК ИНВЕНТАРЯ
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

-- Фильтруем инвентарь по TARGET_ID. type_id: 0 = блоки, 2 = семена
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
-- 🌀 НАДЕЖНЫЙ УМНЫЙ ПЕРЕХОДЧИК
-------------------------------------------------
local function smart_warp(portal_id)
    local target_world_clean = portal_id:match("^([^:]+)")
    
    while true do
        local state = bot:state()
        if state == "InWorld" then
            local current_world = bot:get_world_name()
            if current_world and current_world:upper() == target_world_clean:upper() then
                sleep_ms(500) 
                return true 
            else
                log(string.format("🌍 Переход из чужого мира (%s) в %s", tostring(current_world), portal_id))
                pcall(function() bot:warp(portal_id) end)
                sleep_ms(3500)
            end
        elseif state == "MenuIdle" then
            log("📺 Бот в меню. Отправляем варп на " .. portal_id)
            pcall(function() bot:warp(portal_id) end)
            sleep_ms(4000)
        elseif state == "Connecting" then
            sleep_ms(500)
        else
            log("🔌 Офлайн. Переподключение...")
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

-- 1. ПОСАДКА (С АВТОПЕРЕКЛЮЧЕНИЕМ НА БРЕЙК ПРИ 0 СЕМЯН)
local function phase_plant()
    log("🌱 Начинаем фазу посадки...")
    
    -- 🛑 ПРОВЕРКА НА СТАРТЕ: Если семян вообще 0, сразу шлем бота ломать блоки
    if count_items(2) == 0 then
        log("⚠️ Семена на нуле! Сажать нечего. Экстренно переходим к инста-брейку блоков.")
        safe_storage.set("phase", "break")
        return
    end

    smart_warp(PORTAL_FARM)
    
    for x = FARM_X1, FARM_X2 do
        if bot:state() ~= "InWorld" then smart_warp(PORTAL_FARM) end
        
        -- Если семена закончились прямо в процессе посадки посреди поля
        if count_items(2) == 0 then
            log("⚠️ Семена закончились во время посадки. Сворачиваемся и уходим на брейк.")
            safe_storage.set("phase", "break")
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

-- 2. МОНИТОР РОСТА
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
            log("❌ Грядка полностью пуста. Проверяем запасы для перепосадки.")
            safe_storage.set("phase", "plant")
            return
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
    log("🧲 Сбор выпавших блоков и семян...")
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
        local blocks_count = count_items(0) -- Блоки (тип 0)
        log("📦 Блоков в инвентаре осталось разрушить: " .. blocks_count)
        
        -- Если ломать больше нечего (или осталось слишком мало), выходим из цикла
        if blocks_count < 10 then 
            log("✅ Все блоки из инвентаря успешно разбиты в крошку.")
            break 
        end
        
        smart_warp(PORTAL_BREAK)
        
        local pos = bot:pos()
        if pos then
            local px, py = pos.tile_x, pos.tile_y
            local targets = { {px - 1, py}, {px + 1, py}, {px, py + 1} }
            
            log("💥 Уничтожение пакетами урона...")
            for _, t in ipairs(targets) do
                for i = 1, 15 do
                    bot:send("SB", {x = t[1], y = t[2], BlockType = TARGET_ID}) 
                    local packet_hits = HITS_PER_BLOCK + 2 
                    for j = 1, packet_hits do 
                        bot:send("HB", {x = t[1], y = t[2]}) 
                    end
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

-- 6. СБРОС ИЗЛИШКОВ СЕМЯН
local function phase_drop()
    local current_seeds = count_items(2) -- Семена (тип 2)
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
    -- Возвращаемся на посадку, теперь у нас точно должны быть семена после брейка
    safe_storage.set("phase", "plant")
end

-------------------------------------------------
-- 🔄 ГЛАВНЫЙ ЦИКЛ БОТА
-------------------------------------------------
runThread(function()
    log(string.format("🚀 Фарм-машина v5.7 УСПЕШНО ЗАПУЩЕНА! Защита от пустых семян активна."))
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
