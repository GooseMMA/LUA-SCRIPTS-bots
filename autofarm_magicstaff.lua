-- DEEP NETHER FARMER - FIXED EXIT & KICK ISSUES
-- Proper exit packet handling + delays

local BOT_IDS = getBots()
if not BOT_IDS or #BOT_IDS == 0 then error("[GLOBAL] No bots") end

math.randomseed(now_ms())

local C = {
    DEEP_NETHER = "DEEPNETHER",
    BASE_WORLDS = { "TEST020", "TEST021", "TEST022" },
    
    EXIT_PKT = "eQEo",
    EXIT_BLOCK = 1502,
    
    LOOP_DELAY = 5000,  -- Increased delay between runs
    
    PATH_TIMEOUT = 25000,
    
    GATES_WAIT = 90000,
    AFTER_GATES_DELAY = 1500,
    
    ENTER_TIMEOUT = 40000,
    RETURN_TIMEOUT = 25000,
    CONNECT_TIMEOUT = 20000,
    
    -- Exit timing
    EXIT_SEND_DELAY = 800,     -- Wait after sending exit packet
    EXIT_WARP_DELAY = 1200,    -- Wait before warping after exit
    
    PZlO = "PZlO",
    sGha = "sGha",
    ppIX = "ppIX",
    jcpA = "jcpA",
    
    MAX_BOTS = 100,
}

local workers = {}
local GLOBAL = { runs = 0, completed = 0, failed = 0 }

local function now() return now_ms() end

local function random_base(index)
    if #C.BASE_WORLDS == 0 then return "TEST020" end
    local shift = math.random(0, #C.BASE_WORLDS - 1)
    return C.BASE_WORLDS[((index + shift - 1) % #C.BASE_WORLDS) + 1]
end

local function mk_worker(bot_id, index)
    local w = {}
    w.id = bot_id
    w.index = index
    w.bot = getBot(bot_id)
    w.name = w.bot:name()
    w.base = random_base(index)
    w.run_id = 0
    w.gates_seen = false
    w.gates_time = 0
    w.exit_sent = false
    
    w.stat = { runs = 0, completed = 0, failed = 0 }
    
    function w:log(msg) log("[" .. self.name .. "] " .. msg) end
    function w:state() return tostring(self.bot:state()) end
    function w:world() return tostring(self.bot:get_world_name()) end
    function w:alive() return self:state() == "InWorld" end
    function w:pos() 
        local p = self.bot:pos() 
        return p.tile_x or 0, p.tile_y or 0 
    end
    
    function w:bad_state()
        local s = self:state()
        return s == "Disconnected" or s == "Failed" or s == "MenuIdle"
    end
    
    function w:try_connect()
        pcall(function() self.bot:connect() end)
    end
    
    function w:wait_connected(timeout)
        local dl = now() + (timeout or C.CONNECT_TIMEOUT)
        while now() < dl do
            local s = self:state()
            if s == "InWorld" or s == "MenuIdle" then return true end
            if s == "Disconnected" or s == "Failed" then self:try_connect() end
            sleep(500)
        end
        return self:state() == "InWorld" or self:state() == "MenuIdle"
    end
    
    function w:warp_base()
        if self:alive() and self:world() == self.base then return true end
        if not self:wait_connected(C.CONNECT_TIMEOUT) then return false end
        
        for i = 1, 3 do
            pcall(function() self.bot:warp(self.base, false) end)
            local dl = now() + C.RETURN_TIMEOUT
            while now() < dl do
                if self:state() == "InWorld" and self:world() == self.base then
                    sleep(500)  -- Settle time
                    return true
                end
                if self:bad_state() then self:try_connect() end
                sleep(500)
            end
        end
        return false
    end
    
    function w:is_deep_nether()
        return self:world() == C.DEEP_NETHER
    end
    
    function w:find_exit()
        local tiles = self.bot:findTiles(C.EXIT_BLOCK)
        if #tiles > 0 then return tiles[1] end
        return nil
    end
    
    function w:enter_deep_nether()
        if self:is_deep_nether() and self:alive() then
            self:log("[ENTER] already in Deep Nether")
            return true
        end
        
        self.gates_seen = false
        self.gates_time = 0
        self.exit_sent = false
        
        self.bot:send(C.PZlO, {})
        self.bot:send(C.sGha, { zNds = { 0 } })
        self.bot:send(C.ppIX, { UUEW = C.DEEP_NETHER, BaaD = true })
        
        self:log("[ENTER] warping to " .. C.DEEP_NETHER)
        
        local dl = now() + C.ENTER_TIMEOUT
        while now() < dl do
            sleep(500)
            if self:alive() and self:is_deep_nether() then
                sleep(1000)  -- Settle after enter
                self:log("[ENTER] success")
                return true
            end
            if self:bad_state() then
                self:try_connect()
            end
        end
        
        self:log("[ENTER] timeout")
        return false
    end
    
    function w:wait_gates()
        self:log("[GATES] waiting...")
        local dl = now() + C.GATES_WAIT
        
        while now() < dl do
            if not self:alive() or not self:is_deep_nether() then
                return false
            end
            
            if self.gates_seen then
                local elapsed = now() - self.gates_time
                if elapsed >= C.AFTER_GATES_DELAY then
                    self:log("[GATES] opened!")
                    return true
                end
            end
            
            sleep(300)
        end
        
        self:log("[GATES] timeout, proceeding anyway")
        return true
    end
    
    function w:walk_to_exit()
        local exit = self:find_exit()
        if not exit then
            self:log("[WALK] no exit found!")
            return false
        end
        
        local px, py = self:pos()
        self:log("[WALK] from " .. px .. "," .. py .. " to " .. exit.x .. "," .. exit.y)
        
        local ok, err = pcall(function()
            self.bot:find_path(exit.x, exit.y)
        end)
        
        if not ok then
            self:log("[WALK] find_path failed: " .. tostring(err))
            return false
        end
        
        local ax, ay = self:pos()
        self:log("[WALK] arrived at " .. ax .. "," .. ay)
        sleep(500)  -- Settle at exit
        return true
    end
    
    function w:exit_deep_nether()
        local exit = self:find_exit()
        if not exit then
            self:log("[EXIT] no exit found")
            return false
        end
        
        self:log("[EXIT] at pos " .. tostring(self:pos()))
        self:log("[EXIT] sending " .. C.EXIT_PKT .. " x=" .. exit.x .. " y=" .. exit.y)
        
        -- Send exit packet
        pcall(function() 
            self.bot:send(C.EXIT_PKT, { x = exit.x, y = exit.y }) 
        end)
        
        self.exit_sent = true
        
        -- ✅ Wait for server to process exit packet
        self:log("[EXIT] waiting " .. C.EXIT_SEND_DELAY .. "ms for server...")
        sleep(C.EXIT_SEND_DELAY)
        
        -- Check if still in Deep Nether
        if self:is_deep_nether() then
            self:log("[EXIT] still in Deep Nether, warping to base...")
        end
        
        -- ✅ Wait before warping
        sleep(C.EXIT_WARP_DELAY)
        
        self:log("[EXIT] warping to " .. self.base)
        pcall(function() self.bot:warp(self.base, false) end)
        
        local dl = now() + C.RETURN_TIMEOUT
        while now() < dl do
            if self:alive() and self:world() == self.base then
                sleep(500)  -- Settle
                self:log("[EXIT] arrived at base")
                return true
            end
            if self:bad_state() then 
                self:log("[EXIT] bad state, reconnecting...")
                self:try_connect() 
            end
            sleep(500)
        end
        
        self:log("[EXIT] timeout waiting for base, state=" .. self:state())
        return false
    end
    
    function w:run_once()
        self.run_id = self.run_id + 1
        self.stat.runs = self.stat.runs + 1
        GLOBAL.runs = GLOBAL.runs + 1
        
        self:log("=== RUN " .. self.run_id .. " ===")
        self:log_state("[RUN] start")
        
        -- Reset flags
        self.exit_sent = false
        
        if not self:warp_base() then
            self:log("[RUN] failed to warp to base")
            self.stat.failed = self.stat.failed + 1
            GLOBAL.failed = GLOBAL.failed + 1
            return false
        end
        
        sleep(1000)  -- Settle in base
        
        if not self:enter_deep_nether() then
            self:log("[RUN] failed to enter Deep Nether")
            self.stat.failed = self.stat.failed + 1
            GLOBAL.failed = GLOBAL.failed + 1
            return false
        end
        
        if not self:wait_gates() then
            self:log("[RUN] gates wait failed")
            self.stat.failed = self.stat.failed + 1
            GLOBAL.failed = GLOBAL.failed + 1
            return false
        end
        
        if not self:walk_to_exit() then
            self:log("[RUN] walk to exit failed")
            self.stat.failed = self.stat.failed + 1
            GLOBAL.failed = GLOBAL.failed + 1
            return false
        end
        
        if not self:exit_deep_nether() then
            self:log("[RUN] exit failed")
            self.stat.failed = self.stat.failed + 1
            GLOBAL.failed = GLOBAL.failed + 1
            return false
        end
        
        self.stat.completed = self.stat.completed + 1
        GLOBAL.completed = GLOBAL.completed + 1
        self:log("[DONE] completed! runs=" .. self.stat.runs .. " ok=" .. self.stat.completed)
        self:log_state("[DONE] end")
        
        return true
    end
    
    function w:log_state(tag)
        local x, y = self:pos()
        self:log(tag .. " state=" .. self:state() .. " world=" .. self:world() .. " pos=" .. x .. "," .. y)
    end
    
    function w:install()
        pcall(function() self.bot:off(events.PACKET_RECEIVED) end)
        pcall(function() self.bot:off(events.STATE_CHANGED) end)
        
        self.bot:on(events.PACKET_RECEIVED, function(pkt)
            if not pkt or not pkt.ids then return end
            
            for _, id in ipairs(pkt.ids) do
                if id == C.jcpA then
                    self.gates_seen = true
                    self.gates_time = now()
                    self:log("[PACKET] gates opened (jcpA)")
                end
                if id == "rwAQ" then
                    self:log("[PACKET] warp confirmed (rwAQ)")
                end
                if id == "Cggg" then
                    self:log("[PACKET] respawn (Cggg)")
                end
            end
        end)
        
        self.bot:on(events.STATE_CHANGED, function(data)
            self:log("[STATE] " .. data.state)
        end)
    end
    
    function w:loop()
        self:install()
        self:log("[START] worker started")
        
        while true do
            local ok, err = pcall(function()
                self:run_once()
            end)
            
            if not ok then
                self.stat.failed = self.stat.failed + 1
                GLOBAL.failed = GLOBAL.failed + 1
                self:log("[ERROR] " .. tostring(err))
            end
            
            -- Ensure back in base
            if not self:alive() or self:world() ~= self.base then
                self:log("[LOOP] recovering to base...")
                self:warp_base()
            end
            
            self:log("[LOOP] sleep " .. C.LOOP_DELAY .. "ms")
            sleep(C.LOOP_DELAY)
        end
    end
    
    return w
end

local count = math.min(#BOT_IDS, C.MAX_BOTS)
for i = 1, count do
    local w = mk_worker(BOT_IDS[i], i)
    workers[BOT_IDS[i]] = w
    w:log("[INIT] base=" .. w.base)
end

log("========================================")
log("[GLOBAL] DEEP NETHER FARMER - FIXED")
log("[GLOBAL] Proper exit packet handling")
log("[GLOBAL] bots=" .. count)
log("========================================")

for i = 1, count do
    runThread(function()
        workers[BOT_IDS[i]]:loop()
    end)
end

runThread(function()
    while true do
        sleep(60000)
        log("========================================")
        log("[STATS] runs=" .. GLOBAL.runs .. " completed=" .. GLOBAL.completed .. " failed=" .. GLOBAL.failed)
        log("========================================")
    end
end)

while true do sleep(1000) end

