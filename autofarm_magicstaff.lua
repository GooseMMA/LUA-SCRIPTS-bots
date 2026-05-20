 Features:
• Multi-bot butterfly farming
• Random world scanning
• Auto hunt, collect, and store
• Multiple Storage World Support
• Rarity + Byte Coin tracking
• Discord webhook reports
• Auto reconnect/rejoin
• Remote price list support (will update the price list if I`m not lazy)
• Customizable World Scanning Time

Tips: World Scanning Time is 5 minutes default, if you don't get much butterflies from it. Feel free to change it.

Note : This is an AI-Assisted Script. Some features like dropping butterfly may fail sometimes and butterflies not registered in the webhook but breaking butterfly and world scanning perfectly works.

    --  ┳┓        ┏┓    ┓┏         
--  ┣┫┓┏╋╋┏┓┏┓╋┃┓┏  ┣┫┓┏┏┓╋┏┓┏┓
--  ┻┛┗┻┗┗┗ ┛ ┛┗┗┫  ┛┗┗┻┛┗┗┗ ┛ 
--               ┛                                       
--  ┳┓    ┳┓•┓┓  ┓     ┓       ┓  ┏┓┓    ┏┓┏┓┏┳┓
--  ┣┫┓┏  ┣┫┓┃┃┓┏┣┓┏┓┏┓┃  ┏┓┏┓┏┫  ┃ ┣┓┏┓╋┃┓┃┃ ┃ 
--  ┻┛┗┫  ┻┛┗┗┗┗┫┗┛┗┛┗┛┗  ┗┻┛┗┗┻  ┗┛┛┗┗┻┗┗┛┣┛ ┻ 
--     ┛        ┛                             

local WEBHOOK_URL = "Webhook URL HERE"
local ENABLE_WEBHOOK = true

local WEBHOOK_BOT_NAME = "Butterfly Hunter"
local WEBHOOK_AVATAR_URL = "https://i.ibb.co/HDFWMS7w/New-Project.png"
local PROGRAM_NAME = "Butterfly Hunter"
local WEBHOOK_EMBED_COLOR = 0x81D8D0

local RARITY_STYLE = {
    ["Common"] = { label = "White", emoji = "⚪", rank = 1 },
    ["Uncommon"] = { label = "Green", emoji = "🟢",rank = 2 },
    ["Rare"] = { label = "Blue", emoji = "🔵", rank = 3 },
    ["Ultra Rare"] = { label = "Purple", emoji = "🟣", rank = 4 },
    ["Legendary"] = { label = "Yellow", emoji = "🟡", rank = 5 },
    ["Unknown"] = { label = "Gray", emoji = "⚫", rank = 0 },
}

local RARITY_ORDER = {
    ["Legendary"] = 5,
    ["Ultra Rare"] = 4,
    ["Rare"] = 3,
    ["Uncommon"] = 2,
    ["Common"] = 1,
    ["Unknown"] = 0,
}


local PRICE_LIST_URL = "https://gist.githubusercontent.com/NikolaNurmeghabib/b0d65946bf94c67f71591659adb94a17/raw/gistfile1.txt"
local PRICE_UPDATE_INTERVAL_MS = 43200000 

-- Multiple storage / portal worlds.
-- Add as many as you want.
-- The bot will randomly choose one each time it stores butterflies.
local SAVE_WORLDS = {
    "World1:ID",
    "World2:ID2",
}

local USE_STORAGE_POSITION = false
local STORAGE_DROP_X = 10
local STORAGE_DROP_Y = 5

local MAX_DROP_UP_STEPS = 15
local PORTAL_DROP_STEPS = {}

local MIN_WORLD_LENGTH = 7
local MAX_WORLD_LENGTH = 8

local MONITOR_WORLD_MS = 300000       -- 5 minutes per random world (to change please use miliseconds)
local SCAN_INTERVAL_MS = 3000         

local BREAK_HITS = 8
local HIT_DELAY_MS = 250
local AFTER_PATH_DELAY_MS = 1800
local PATH_TO_BUTTERFLY_TIMEOUT_MS = 12000

local AUTO_COLLECT_AFTER_BREAK_MS = 10000
local AUTO_COLLECT_INTERVAL_MS = 150

local RECONNECT_WAIT_MS = 4000
local WARP_TIMEOUT_MS = 60000
local REJOIN_ATTEMPTS = 15

local BOT_START_DELAY_MS = 3000

local WEBHOOK_STATS_INTERVAL_MS = 300000 -- sends webhook every 5 minutes only (to change please us miliseconds)

local BUTTERFLY_QUEST_ITEMS = {
    [1] = { id = 1691, name = "Empress Butterfly", rarity = "Common" },
    [2] = { id = 1732, name = "Green Nurse Moth", rarity = "Common" },
    [3] = { id = 1692, name = "Orange Tipper Butterfly", rarity = "Common" },
    [4] = { id = 1694, name = "Black Lightning Butterfly", rarity = "Common" },
    [5] = { id = 1729, name = "Diaper Moth", rarity = "Common" },
    [6] = { id = 1696, name = "Garden Maid Butterfly", rarity = "Common" },
    [7] = { id = 1702, name = "Pearl Heath Butterfly", rarity = "Common" },
    [8] = { id = 1734, name = "Siren Hawk Moth", rarity = "Common" },
    [9] = { id = 1703, name = "Small Tortoiseshell Butterfly", rarity = "Common" },
    [10] = { id = 1704, name = "Small Brimstone Butterfly", rarity = "Common" },
    [11] = { id = 1737, name = "White Nun Moth", rarity = "Common" },
    [12] = { id = 1707, name = "Birch Glider Butterfly", rarity = "Common" },
    [13] = { id = 1715, name = "Pale Legate Butterfly", rarity = "Common" },
    [14] = { id = 1740, name = "Stud Moth", rarity = "Common" },
    [15] = { id = 1741, name = "Bittywee Hawk Moth", rarity = "Common" },
    [16] = { id = 1719, name = "Crush Pearl Butterfly", rarity = "Common" },
    [17] = { id = 1720, name = "Dirty Lemon Butterfly", rarity = "Common" },
    [18] = { id = 1744, name = "Lemon Moth", rarity = "Common" },
    [19] = { id = 1746, name = "Willowherb Hawk Moth", rarity = "Common" },
    [20] = { id = 1725, name = "Green Dwarf Butterfly", rarity = "Common" },
    [21] = { id = 1748, name = "Red Dot Moth", rarity = "Common" },
    [22] = { id = 1727, name = "Blue Dwarf Butterfly", rarity = "Common" },
    [23] = { id = 1728, name = "Paper Kite Butterfly", rarity = "Common" },

    [24] = { id = 1690, name = "Tiger Longtail Butterfly", rarity = "Uncommon" },
    [25] = { id = 1730, name = "Rose Moth", rarity = "Uncommon" },
    [26] = { id = 1698, name = "Blue Emperor Butterfly", rarity = "Uncommon" },
    [27] = { id = 1705, name = "Blue Eyed Empress Butterfly", rarity = "Uncommon" },
    [28] = { id = 1736, name = "Camouflage Moth", rarity = "Uncommon" },
    [29] = { id = 1706, name = "Admiral Butterfly", rarity = "Uncommon" },
    [30] = { id = 1708, name = "Blue Bottom Butterfly", rarity = "Uncommon" },
    [31] = { id = 1739, name = "Bedstraw Hawk Moth", rarity = "Uncommon" },
    [32] = { id = 1711, name = "Shadow Longtail Butterfly", rarity = "Uncommon" },
    [33] = { id = 1749, name = "Burp Moth", rarity = "Uncommon" },

    [34] = { id = 1723, name = "Pink Delight Butterfly", rarity = "Rare" },
    [35] = { id = 1689, name = "Zebra Longtail Butterfly", rarity = "Rare" },
    [36] = { id = 1738, name = "Green Nun Moth", rarity = "Rare" },
    [37] = { id = 1695, name = "Monkey Bum Butterfly", rarity = "Rare" },
    [38] = { id = 1700, name = "Red Orchae Butterfly", rarity = "Rare" },
    [39] = { id = 1742, name = "Peacock Moth", rarity = "Rare" },
    [40] = { id = 1701, name = "Rainbow Chitoria Butterfly", rarity = "Rare" },
    [41] = { id = 1710, name = "Neon Striper Butterfly", rarity = "Rare" },
    [42] = { id = 1716, name = "Lilium Haste Butterfly", rarity = "Rare" },
    [43] = { id = 1747, name = "Peacock Behemoth", rarity = "Rare" },
    [44] = { id = 1724, name = "Blue Knight Butterfly", rarity = "Rare" },
    [45] = { id = 1750, name = "Blood Moth", rarity = "Rare" },
    [46] = { id = 1726, name = "Yellow Dwarf Butterfly", rarity = "Rare" },

    [47] = { id = 1699, name = "Gray Glass Wing Butterfly", rarity = "Ultra Rare" },
    [48] = { id = 1731, name = "Poison Wing Butterfly", rarity = "Ultra Rare" },
    [49] = { id = 1709, name = "Pink Cheeks Butterfly", rarity = "Ultra Rare" },
    [50] = { id = 1743, name = "Blue Night Butterfly", rarity = "Ultra Rare" },
    [51] = { id = 1713, name = "Apollon Butterfly", rarity = "Ultra Rare" },
    [52] = { id = 1751, name = "Lava Moth", rarity = "Ultra Rare" },
    [53] = { id = 1714, name = "Blue Ivory Butterfly", rarity = "Ultra Rare" },
    [54] = { id = 1745, name = "Skull Hawk Moth", rarity = "Ultra Rare" },
    [55] = { id = 1718, name = "Purple Haze Butterfly", rarity = "Ultra Rare" },

    [56] = { id = 1693, name = "Pink Heart Butterfly", rarity = "Legendary" },
    [57] = { id = 1733, name = "Salamander Moth", rarity = "Legendary" },
    [58] = { id = 1697, name = "Night Sky Butterfly", rarity = "Legendary" },
    [59] = { id = 1735, name = "Polilla Gigante", rarity = "Legendary" },
    [60] = { id = 1717, name = "Lava Aglais Butterfly", rarity = "Legendary" },
    [61] = { id = 1712, name = "Orange Tiger Tip Butterfly", rarity = "Legendary" },
    [62] = { id = 1721, name = "Azure Flapper Butterfly", rarity = "Legendary" },
    [63] = { id = 1722, name = "Violet Colossus Butterfly", rarity = "Legendary" },
    [64] = { id = 1752, name = "Emerald Hawk Moth", rarity = "Legendary" },
}

local BUTTERFLY_IDS = {}
local BUTTERFLY_LOOKUP = {}
local BUTTERFLY_ITEM_LOOKUP = {}
local BUTTERFLY_INFO_BY_ID = {}

local BUTTERFLY_BLOCK_IDS = {
    [1685] = true,
    [1686] = true,
    [1687] = true,
    [1688] = true,
}

for questIndex, item in pairs(BUTTERFLY_QUEST_ITEMS) do
    BUTTERFLY_ITEM_LOOKUP[item.id] = true

    BUTTERFLY_INFO_BY_ID[item.id] = {
        quest = questIndex,
        id = item.id,
        name = item.name,
        rarity = item.rarity
    }
end

for id = 1685, 1752 do
    BUTTERFLY_IDS[#BUTTERFLY_IDS + 1] = id
    BUTTERFLY_LOOKUP[id] = true

    if not BUTTERFLY_INFO_BY_ID[id] then
        BUTTERFLY_INFO_BY_ID[id] = {
            quest = 0,
            id = id,
            name = "Unlisted Butterfly",
            rarity = "Unknown"
        }
    end
end

table.sort(BUTTERFLY_IDS)

local function getButterflyInfo(id)
    return BUTTERFLY_INFO_BY_ID[id] or {
        quest = 0,
        id = id,
        name = "Unknown Butterfly",
        rarity = "Unknown"
    }
end

local function getRarityStyle(rarity)
    return RARITY_STYLE[rarity] or RARITY_STYLE["Unknown"]
end

local function formatRarityLabel(rarity)
    local style = getRarityStyle(rarity)
    return (style.emoji or "⚫") .. " " .. rarity
end

local function formatButterflyLabel(id)
    local info = getButterflyInfo(id)
    return string.format("%s %s (#%d)", formatRarityLabel(info.rarity), info.name, id)
end

local function isButterflyBlockId(id)
    return BUTTERFLY_BLOCK_IDS[id] == true
end

local function isButterflyItemId(id)
    return BUTTERFLY_ITEM_LOOKUP[id] == true
end

local function isButterflyInventoryItem(item)
    if not item then return false end

    if item.id and isButterflyBlockId(item.id) then
        return false
    end

    if item.id and BUTTERFLY_ITEM_LOOKUP[item.id] then
        return true
    end

    local name = tostring(item.name or ""):lower()
    if name:find("butterfly", 1, true) or name:find("moth", 1, true) then
        return true
    end

    return false
end


local STATS = {
    started_at = now_ms(),
    butterflies_caught = 0, 
    storage_saves = 0,
    items_saved = 0,
    worlds_checked = 0,
    failed_paths = 0,
    reconnects = 0,
    spawn_found = 0,
    current_bots = 0,
    last_storage_world = "none",
    last_update = "Script started",
    caught_by_id = {}
}

local ITEM_PRICES = {}
local LAST_PRICE_UPDATE = 0
local LAST_WEBHOOK_STATS = 0

local function jsonEscape(text)
    text = tostring(text or "")
    text = text:gsub('\\', '\\\\')
    text = text:gsub('"', '\\"')
    text = text:gsub('\n', '\\n')
    text = text:gsub('\r', '')
    return text
end

local function formatNum(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    local sign = ""
    if s:sub(1, 1) == "-" then
        sign = "-"
        s = s:sub(2)
    end
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. formatted
end

local function plainWebhook(content)
    if not ENABLE_WEBHOOK then return end
    if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "PUT_YOUR_DISCORD_WEBHOOK_HERE" then
        log("[Webhook not set]", content)
        return
    end

    local ok = false
    local payload = {
        username = WEBHOOK_BOT_NAME,
        content = content
    }

    if WEBHOOK_AVATAR_URL and WEBHOOK_AVATAR_URL ~= "" and WEBHOOK_AVATAR_URL ~= "PUT_IMAGE_URL_HERE" then
        payload.avatar_url = WEBHOOK_AVATAR_URL
    end

    if http and http.post then
        ok = pcall(function()
            http.post(WEBHOOK_URL, { json = payload, timeout = 10000 })
        end)
    end

    if not ok and http_post then
        ok = pcall(function()
            http_post(WEBHOOK_URL, payload)
        end)
    end

    if not ok and request then
        local avatarPart = ""
        if payload.avatar_url then
            avatarPart = ',"avatar_url":"' .. jsonEscape(payload.avatar_url) .. '"'
        end

        local body = '{"username":"' .. jsonEscape(WEBHOOK_BOT_NAME) .. '"' .. avatarPart .. ',"content":"' .. jsonEscape(content) .. '"}'
        ok = pcall(function()
            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
    end

    if not ok then
        log("[Webhook failed or HTTP unsupported]", content)
    end
end

local function postWebhookPayload(payload, fallbackText)
    if not ENABLE_WEBHOOK then return end
    if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "PUT_YOUR_DISCORD_WEBHOOK_HERE" then
        log("[Webhook not set]", fallbackText or "payload")
        return
    end

    payload.username = payload.username or WEBHOOK_BOT_NAME
    if WEBHOOK_AVATAR_URL and WEBHOOK_AVATAR_URL ~= "" and WEBHOOK_AVATAR_URL ~= "PUT_IMAGE_URL_HERE" then
        payload.avatar_url = WEBHOOK_AVATAR_URL
    end

    local ok = false

    if http and http.post then
        ok = pcall(function()
            http.post(WEBHOOK_URL, { json = payload, timeout = 10000 })
        end)
    end

    if not ok and http_post then
        ok = pcall(function()
            http_post(WEBHOOK_URL, payload)
        end)
    end

    if not ok then
        plainWebhook(fallbackText or (PROGRAM_NAME .. " stats update"))
    end
end

local function httpGetText(url)
    if not url or url == "" or url == "PUT_RAW_PRICE_LIST_URL_HERE" then
        return nil
    end

    local text = nil

    if http and http.get then
        local ok, res = pcall(function()
            return http.get(url, { timeout = 10000 })
        end)

        if ok and res then
            if type(res) == "table" then
                text = res.body or res.Body or res.data or res.Data
            else
                text = tostring(res)
            end
        end
    end

    if not text and request then
        local ok, res = pcall(function()
            return request({
                Url = url,
                Method = "GET",
                Headers = { ["Cache-Control"] = "no-cache" }
            })
        end)

        if ok and res then
            text = res.Body or res.body
        end
    end

    return text
end

local function parsePriceList(text)
    local prices = {}
    local count = 0

    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        line = line:gsub("^\239\187\191", "")

        line = line:gsub("#.*", "")

        line = line:gsub("%s+", "")

        local id, price = line:match("^(%d+)=(%d+)$")

        if id and price then
            prices[tonumber(id)] = tonumber(price)
            count = count + 1
        end
    end

    return prices, count
end

local function updatePricesIfNeeded(force)
    local currentTime = now_ms()

    if not force and LAST_PRICE_UPDATE > 0 and currentTime - LAST_PRICE_UPDATE < PRICE_UPDATE_INTERVAL_MS then
        return true
    end

    local text = httpGetText(PRICE_LIST_URL)

    if not text or text == "" then
        if force then
            log("[Prices] Remote price list not loaded. Set PRICE_LIST_URL to enable Byte Coins pricing.")
        end
        return false
    end

    local prices, count = parsePriceList(text)

    if count <= 0 then
        log("[Prices] Remote price list loaded but no valid item_id=price lines were found.")
        return false
    end

    ITEM_PRICES = prices
    LAST_PRICE_UPDATE = currentTime

    log("[Prices] Updated", count, "Byte Coins prices from remote list.")
    return true
end

local function getItemPrice(id)
    return ITEM_PRICES[id] or 0
end

local function getHighestCaughtRarityStyle()
    local best = RARITY_STYLE["Unknown"]

    for id, amount in pairs(STATS.caught_by_id) do
        if amount and amount > 0 then
            local info = getButterflyInfo(id)
            local style = getRarityStyle(info.rarity)

            if style.rank > best.rank then
                best = style
            end
        end
    end

    return best
end

local function cleanButterflyName(name)
    name = tostring(name or "Unknown")
    name = name:gsub(" Butterfly$", "")
    name = name:gsub(" Moth$", "")
    return name
end

local function shortenText(text, maxLen)
    text = tostring(text or "")
    maxLen = maxLen or 24

    if #text <= maxLen then
        return text
    end

    if maxLen <= 3 then
        return text:sub(1, maxLen)
    end

    return text:sub(1, maxLen - 3) .. "..."
end

local function calculateByteCoinStats()
    updatePricesIfNeeded(false)

    local total = 0
    local groups = {}
    local rarityOrder = { "Legendary", "Ultra Rare", "Rare", "Uncommon", "Common", "Unknown" }

    for id, amount in pairs(STATS.caught_by_id) do
        amount = tonumber(amount) or 0

        if amount > 0 then
            local info = getButterflyInfo(id)
            local rarity = info.rarity or "Unknown"
            local price = getItemPrice(id)
            local value = price * amount

            total = total + value

            if not groups[rarity] then
                groups[rarity] = {
                    items = {},
                    subtotal = 0,
                    totalAmount = 0
                }
            end

            groups[rarity].subtotal = groups[rarity].subtotal + value
            groups[rarity].totalAmount = groups[rarity].totalAmount + amount

            table.insert(groups[rarity].items, {
                name = cleanButterflyName(info.name or ("Item " .. tostring(id))),
                amount = amount,
                price = price,
                value = value
            })
        end
    end

    local fields = {}

    table.insert(fields, {
        name = "❖ Butterfly Caught",
        value = "Grouped by rarity • 🪙 = Byte Coins",
        inline = false
    })

    local hasAny = false

    for _, rarity in ipairs(rarityOrder) do
        local group = groups[rarity]

        if group and #group.items > 0 then
            hasAny = true

            table.sort(group.items, function(a, b)
                if a.amount == b.amount then
                    return tostring(a.name) < tostring(b.name)
                end
                return a.amount > b.amount
            end)

            local valueText = "```"
            local hidden = 0

            for i, item in ipairs(group.items) do
    
                local displayName = shortenText(item.name, 22)
                local line = string.format(
                    "%-22s : %sx  🪙 %s\n",
                    displayName,
                    formatNum(item.amount),
                    formatNum(item.value)
                )

                if #valueText + #line > 860 then
                    hidden = #group.items - i + 1
                    break
                end

                valueText = valueText .. line
            end

            if hidden > 0 then
                valueText = valueText .. "+ " .. hidden .. " more hidden\n"
            end

            valueText = valueText .. string.format("%-22s : 🪙 %s", "Subtotal", formatNum(group.subtotal))
            valueText = valueText .. "```"

            table.insert(fields, {
                name = string.format("%s **%s** (Total: %s)", formatRarityLabel(rarity):match("^%S+") or "⚫", rarity, formatNum(group.totalAmount)),
                value = valueText,
                inline = false
            })
        end
    end

    if not hasAny then
        fields = {{
            name = "❖ Butterfly Caught",
            value = "No confirmed butterfly items yet.",
            inline = false
        }}
    end

    return total, fields
end

local function formatRuntime(ms)
    local totalSeconds = math.floor(ms / 1000)
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60

    if days > 0 then
        return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    end

    return string.format("%02dh %02dm %02ds", hours, minutes, seconds)
end


local function makeProgressBar(current, goal, width)
    current = tonumber(current) or 0
    goal = tonumber(goal) or 100
    width = tonumber(width) or 18

    if goal <= 0 then
        goal = 100
    end

    local ratio = current / goal
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end

    local filled = math.floor((ratio * width) + 0.5)
    if filled < 0 then filled = 0 end
    if filled > width then filled = width end

    return string.rep("█", filled) .. string.rep("░", width - filled)
end

local function getNextByteCoinGoal(current)
    current = tonumber(current) or 0

    local step = 10000

    if current < step then
        return step
    end

    local nextGoal = math.ceil(current / step) * step
    if nextGoal <= current then
        nextGoal = nextGoal + step
    end

    return nextGoal
end

local function perHour(amount, runtimeMs)
    amount = tonumber(amount) or 0
    runtimeMs = tonumber(runtimeMs) or 0

    local hours = runtimeMs / 3600000
    if hours <= 0 then
        return 0
    end

    return amount / hours
end

local function joinLinesLimited(lines, maxChars)
    maxChars = maxChars or 1000

    if not lines or #lines == 0 then
        return "No confirmed butterfly items yet."
    end

    local out = ""
    local hidden = 0

    for i, line in ipairs(lines) do
        local add = line .. "\n"
        if #out + #add > maxChars then
            hidden = #lines - i + 1
            break
        end
        out = out .. add
    end

    if hidden > 0 then
        out = out .. "+ " .. hidden .. " more item type(s) hidden"
    end

    return out
end

local function sendStatsWebhook(force)

    local currentTime = now_ms()

    if currentTime - LAST_WEBHOOK_STATS < WEBHOOK_STATS_INTERVAL_MS then
        return
    end

    LAST_WEBHOOK_STATS = currentTime

    updatePricesIfNeeded(false)

    local runtimeMs = currentTime - STATS.started_at
    local runtime = formatRuntime(runtimeMs)
    local activeBots = #getBots()
    local totalByteCoins, rarityValueFields = calculateByteCoinStats()
    local byteCoinsPerHour = perHour(totalByteCoins, runtimeMs)
    local butterfliesPerHour = perHour(STATS.butterflies_caught, runtimeMs)
    local itemsSaved = STATS.items_saved or 0
    local itemsSavedPerHour = perHour(itemsSaved, runtimeMs)
    local priceStatus = LAST_PRICE_UPDATE > 0 and ("Updated " .. formatRuntime(currentTime - LAST_PRICE_UPDATE) .. " ago") or "Not loaded"

    local embedColor = WEBHOOK_EMBED_COLOR

    local byteCoinGoal = getNextByteCoinGoal(totalByteCoins)
    local progressBar = makeProgressBar(totalByteCoins, byteCoinGoal, 18)

    local statusText =
        "```\n" ..
        string.format("%-9s : 🟢 ONLINE\n", "Status") ..
        string.format("%-9s : %s\n", "Workers", formatNum(activeBots)) ..
        string.format("%-9s : %s", "Uptime", runtime) ..
        "```"

    local statisticsText =
        "```\n" ..
        string.format("%-28s : %s\n", "Total Butterfly Collected", formatNum(STATS.butterflies_caught)) ..
        string.format("%-28s : %s\n", "Worlds Checked", formatNum(STATS.worlds_checked)) ..
        string.format("%-28s : %s", "Butterfly Collected/Hour", formatNum(butterfliesPerHour)) ..
        "```"

    local progressText =
        "```\n" ..
        "Byte Coin Target : " .. formatNum(byteCoinGoal) .. "\n" ..
        progressBar .. "\n" ..
        formatNum(totalByteCoins) .. " / " .. formatNum(byteCoinGoal) ..
        "```"

    local earningsText =
        "```\n" ..
        string.format("%-17s : 🪙 %s\n", "Total Byte Coins", formatNum(totalByteCoins)) ..
        string.format("%-17s : 🪙 %s", "Byte Coins/Hour", formatNum(byteCoinsPerHour)) ..
        "```"

    local fields = {
        { name = "❖ Hunt Status", value = statusText, inline = false },
        { name = "❖ Statistics", value = statisticsText, inline = false },
        { name = "❖ Progress", value = progressText, inline = false },
    }

    for _, rarityField in ipairs(rarityValueFields) do
        table.insert(fields, rarityField)
    end
    table.insert(fields, { name = "❖ Byte Coin Earnings", value = earningsText, inline = false })
    table.insert(fields, { name = "❖ Price Checker", value = "```" .. priceStatus .. "```", inline = false })

    local payload = {
        username = WEBHOOK_BOT_NAME,
        embeds = {{
            title =  PROGRAM_NAME .. "🦋",
            color = embedColor,
            fields = fields,
            footer = {
                text = PROGRAM_NAME .. " • Webhook by " .. WEBHOOK_BOT_NAME .. " • Every " .. math.floor(WEBHOOK_STATS_INTERVAL_MS / 60000) .. " min"
            }
        }}
    }

    local fallback = PROGRAM_NAME .. " | Runtime: " .. runtime .. " | Bots: " .. activeBots .. " | Caught: " .. STATS.butterflies_caught .. " | Byte Coins: " .. formatNum(totalByteCoins)
    postWebhookPayload(payload, fallback)
end


local function randomLetter()
    return string.char(math.random(65, 90)) -- A-Z
end

local function randomNumber()
    return tostring(math.random(0, 9))
end

local function randomLetterOrNumber()
    if math.random(1, 2) == 1 then
        return randomLetter()
    else
        return randomNumber()
    end
end

local function generateRandomWorld()
    local length = math.random(MIN_WORLD_LENGTH, MAX_WORLD_LENGTH)

    local chars = {}
    chars[1] = randomLetter()

    local hasNumber = false

    for i = 2, length do
        local c = randomLetterOrNumber()
        chars[i] = c

        if tonumber(c) ~= nil then
            hasNumber = true
        end
    end

    if not hasNumber then
        local index = math.random(2, length)
        chars[index] = randomNumber()
    end

    return table.concat(chars)
end

local function getRandomSaveWorld()
    if not SAVE_WORLDS or #SAVE_WORLDS == 0 then
        return "portal"
    end

    return SAVE_WORLDS[math.random(1, #SAVE_WORLDS)]
end

local function isTransitionState(state)
    return (
        state == "Connecting" or
        state == "JoiningWorld" or
        state == "LoadingWorld"
    )
end

local function isBotDisconnected(bot)
    local state = bot:state()

    if isTransitionState(state) then
        return false
    end

    return (
        state == "MenuIdle" or
        state == "Failed" or
        state == "Disconnected" or
        state == "Unknown" or
        not bot:connected()
    )
end

local function waitForInWorldOrMenu(bot, timeoutMs)
    local start = now_ms()

    while now_ms() - start < timeoutMs do
        local state = bot:state()

        if state == "InWorld" or state == "MenuIdle" then
            return true, state
        end

        sleep_ms(500)
    end

    return false, bot:state()
end

local function hardRecoverBot(bot, botId, targetWorld, reason)
    reason = reason or "unknown"

    STATS.reconnects = STATS.reconnects + 1
    STATS.last_update = "[" .. botId .. "] hard recovering after " .. reason .. " | state: " .. tostring(bot:state())
    sendStatsWebhook(false)

    log(string.format("⚠️ [%s] Hard recovery triggered after %s. State: %s", botId, reason, tostring(bot:state())))

    pcall(function()
        bot:set_auto_collect(false)
    end)

    pcall(function()
        bot:set_auto_reconnect(true)
    end)

    pcall(function()
        bot:disconnect()
    end)

    sleep_ms(1500)

    pcall(function()
        bot:connect()
    end)

    local ok, state = waitForInWorldOrMenu(bot, 20000)

    if not ok then
        log(string.format("❌ [%s] Hard recovery connect timeout. Last state: %s", botId, tostring(state)))
        return false
    end

    if targetWorld and targetWorld ~= "" then
        pcall(function()
            bot:warp(targetWorld)
        end)

        local start = now_ms()
        while now_ms() - start < 30000 do
            local st = bot:state()
            if st == "InWorld" then
                log(string.format("✅ [%s] Hard recovery rejoined %s", botId, targetWorld))
                return true
            end

            if st == "Failed" or st == "Disconnected" or st == "Unknown" then
                pcall(function() bot:connect() end)
                sleep_ms(RECONNECT_WAIT_MS)
                pcall(function() bot:warp(targetWorld) end)
            elseif st == "MenuIdle" then
                pcall(function() bot:warp(targetWorld) end)
            end

            sleep_ms(700)
        end

        log(string.format("❌ [%s] Hard recovery failed to rejoin %s. Last state: %s", botId, targetWorld, tostring(bot:state())))
        return false
    end

    return bot:state() == "InWorld" or bot:state() == "MenuIdle"
end

local function recoverIfFailed(bot, botId, targetWorld, reason)
    local state = bot:state()

    if state == "Failed" or state == "Disconnected" or state == "Unknown" then
        return hardRecoverBot(bot, botId, targetWorld, reason)
    end

    return true
end

local function hasButterfly(bot)
    local ok, items = pcall(function()
        return bot:get_inventory()
    end)

    if not ok or not items then
        return false
    end

    for _, item in ipairs(items) do
        if isButterflyInventoryItem(item) and item.amount > 0 then
            return true
        end
    end

    return false
end

local function countButterflies(bot)
    local total = 0

    local ok, items = pcall(function()
        return bot:get_inventory()
    end)

    if not ok or not items then
        return 0
    end

    for _, item in ipairs(items) do
        if isButterflyInventoryItem(item) and item.amount > 0 then
            total = total + item.amount
        end
    end

    return total
end

local function getButterflyInventoryCounts(items)
    local counts = {}

    if not items then
        return counts
    end

    for _, item in ipairs(items) do
        if isButterflyInventoryItem(item) and item.id and item.amount and item.amount > 0 then
            counts[item.id] = (counts[item.id] or 0) + item.amount
        end
    end

    return counts
end

local function getInventorySnapshot(bot)
    local ok, items = pcall(function()
        return bot:get_inventory()
    end)

    if ok and items then
        return items
    end

    return nil
end

local function forceReconnectAndRejoin(bot, botId, targetWorld)
    STATS.reconnects = STATS.reconnects + 1
    STATS.last_update = "[" .. botId .. "] reconnecting/rejoining " .. targetWorld
    sendStatsWebhook(true)

    log(string.format("⚠️ [%s] Rejoin check. State: %s | Target: %s", botId, bot:state(), targetWorld))

    bot:set_auto_reconnect(true)

    for attempt = 1, REJOIN_ATTEMPTS do
        local state = bot:state()

        if state == "InWorld" then
            log(string.format("✅ [%s] InWorld after rejoin check: %s (attempt %d)", botId, targetWorld, attempt))
            return true
        end

        if isTransitionState(state) then
            sleep_ms(1500)
        else
            if state == "Failed" or state == "Disconnected" or state == "Unknown" then
                pcall(function() bot:set_auto_collect(false) end)
                pcall(function() bot:disconnect() end)
                sleep_ms(1200)
            end

            if not bot:connected() then
                pcall(function()
                    bot:connect()
                end)
                sleep_ms(RECONNECT_WAIT_MS)
            end

            pcall(function()
                bot:warp(targetWorld)
            end)

            sleep_ms(4000)
        end
    end

    log(string.format("❌ [%s] Failed to rejoin %s after %d attempts", botId, targetWorld, REJOIN_ATTEMPTS))
    return false
end
local function warpAndWait(bot, botId, world)
    bot:set_auto_reconnect(true)

    if not bot:connected() then
        pcall(function()
            bot:connect()
        end)
        sleep_ms(RECONNECT_WAIT_MS)
    end

    pcall(function()
        bot:warp(world)
    end)

    local start = now_ms()
    local lastWarpTry = now_ms()
    local lastState = "Unknown"

    while now_ms() - start < WARP_TIMEOUT_MS do
        local state = bot:state()
        lastState = state

        if state == "InWorld" then
            return true
        end

        if state == "MenuIdle" then
            if now_ms() - lastWarpTry > 5000 then
                pcall(function()
                    bot:warp(world)
                end)
                lastWarpTry = now_ms()
            end
        elseif state == "Disconnected" or state == "Failed" or state == "Unknown" then
            if state == "Failed" then
                pcall(function() bot:set_auto_collect(false) end)
                pcall(function() bot:disconnect() end)
                sleep_ms(1200)
            end

            pcall(function()
                bot:connect()
            end)
            sleep_ms(RECONNECT_WAIT_MS)

            pcall(function()
                bot:warp(world)
            end)
            lastWarpTry = now_ms()
        else
            sleep_ms(500)
        end

        sleep_ms(500)
    end

    log(string.format("❌ [%s] Failed to enter %s | Last state: %s", botId, world, tostring(lastState)))
    return false
end


local function getButterflyAmountByItem(items, itemId)
    if not items then return 0 end

    local total = 0

    for _, item in ipairs(items) do
        if item.id == itemId and item.amount and item.amount > 0 then
            total = total + item.amount
        end
    end

    return total
end

local function readInventorySafe(bot, tries)
    tries = tries or 5

    for attempt = 1, tries do
        local ok, items = pcall(function()
            return bot:get_inventory()
        end)

        if ok and items then
            return items
        end

        log(string.format("[%s] Inventory read failed (%d/%d).", bot:name(), attempt, tries))
        sleep_ms(700)
    end

    return nil
end

local function recordButterflyItemStat(itemId, amount, botId)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return 0
    end

    local info = getButterflyInfo(itemId)
    STATS.caught_by_id[itemId] = (STATS.caught_by_id[itemId] or 0) + amount
    STATS.butterflies_caught = STATS.butterflies_caught + amount

    local price = getItemPrice(itemId)
    local value = price * amount

    log(string.format(
        "[%s] Confirmed caught: %s [%s] ID %d x%d | %d Byte Coins each | %d total",
        botId,
        info.name,
        info.rarity,
        itemId,
        amount,
        price,
        value
    ))

    return amount
end

local function recordInventoryGains(beforeItems, afterItems, botId)
    local beforeCounts = getButterflyInventoryCounts(beforeItems)
    local afterCounts = getButterflyInventoryCounts(afterItems)
    local totalGained = 0

    for id, afterAmount in pairs(afterCounts) do
        local beforeAmount = beforeCounts[id] or 0
        local gained = afterAmount - beforeAmount

        if gained > 0 then
            totalGained = totalGained + recordButterflyItemStat(id, gained, botId)
        end
    end

    if totalGained > 0 then
        STATS.last_update = "[" .. botId .. "] inventory confirmed " .. totalGained .. " butterfly item(s) caught"
    end

    return totalGained
end


local function calculateInventoryGains(beforeItems, afterItems)
    local beforeCounts = getButterflyInventoryCounts(beforeItems)
    local afterCounts = getButterflyInventoryCounts(afterItems)
    local gains = {}
    local totalGained = 0

    for id, afterAmount in pairs(afterCounts) do
        local beforeAmount = beforeCounts[id] or 0
        local gained = afterAmount - beforeAmount

        if gained > 0 then
            gains[id] = gained
            totalGained = totalGained + gained
        end
    end

    return totalGained, gains
end

local function snapshotHasButterflyItems(items)
    local counts = getButterflyInventoryCounts(items)

    for _, amount in pairs(counts) do
        if amount and amount > 0 then
            return true
        end
    end

    return false
end

local function recordInventoryGainsWithRetry(bot, beforeItems, botId, tries, delayMs)
    tries = tries or 3
    delayMs = delayMs or 2000

    local lastSnapshot = nil

    for attempt = 1, tries do
        sleep_ms(delayMs)

        local afterItems = getInventorySnapshot(bot)
        lastSnapshot = afterItems

        if afterItems then
            local totalGained = calculateInventoryGains(beforeItems, afterItems)

            log(string.format("[%s] Inventory fetch after break %d/%d: gained %d butterfly item(s).", botId, attempt, tries, totalGained))

            if totalGained > 0 then
                local recorded = recordInventoryGains(beforeItems, afterItems, botId)
                return recorded, afterItems
            end
        else
            log(string.format("[%s] Inventory fetch after break %d/%d failed.", botId, attempt, tries))
        end
    end

    return 0, lastSnapshot
end

local function dropOneButterflyItem(bot, botId, item)
    local beforeItems = readInventorySafe(bot, 3)
    local beforeAmount = getButterflyAmountByItem(beforeItems, item.id)

    if beforeAmount <= 0 then
        return 0
    end

    local dropAmount = item.amount
    if dropAmount > beforeAmount then
        dropAmount = beforeAmount
    end

    for attempt = 1, 2 do
        log(string.format("[%s] Drop attempt %d/2: %s x%d type %s", botId, attempt, formatButterflyLabel(item.id), dropAmount, tostring(item.inventory_type)))

        local dropOk, dropErr = pcall(function()
            -- inventory_type is important for some items; API allows it as the 3rd argument.
            bot:drop(item.id, dropAmount, item.inventory_type)
        end)

        if not dropOk then
            log(string.format("[%s] Drop call failed for item %d: %s", botId, item.id, tostring(dropErr)))
            sleep_ms(800)
        else
            sleep_ms(1200)

            local afterItems = readInventorySafe(bot, 3)
            local afterAmount = getButterflyAmountByItem(afterItems, item.id)
            local actuallyDropped = beforeAmount - afterAmount

            if actuallyDropped > 0 then
                log(string.format("[%s] ✅ Confirmed dropped %s x%d", botId, formatButterflyLabel(item.id), actuallyDropped))
                return actuallyDropped
            end

            log(string.format("[%s] Drop not confirmed for %s. Still has x%d", botId, formatButterflyLabel(item.id), afterAmount))
            sleep_ms(1000)
        end
    end

    log(string.format("[%s] ❌ Failed to drop %s after 2 attempts.", botId, formatButterflyLabel(item.id)))
    return 0
end

local function getPortalDropSteps(saveWorld)
    local steps = PORTAL_DROP_STEPS[saveWorld] or 0

    if steps < 0 then
        steps = 0
    end

    if steps > MAX_DROP_UP_STEPS then
        steps = MAX_DROP_UP_STEPS
    end

    return steps
end

local function moveDropSpotForPortal(bot, botId, saveWorld)
    local stepsUp = getPortalDropSteps(saveWorld)

    if stepsUp <= 0 then
        log("[" .. botId .. "] Drop spot for " .. saveWorld .. ": normal spot.")
        return true
    end

    log("[" .. botId .. "] Drop spot for " .. saveWorld .. ": moving " .. stepsUp .. " tile(s) up.")

    for i = 1, stepsUp do
        local p = bot:pos()
        local upX = p.tile_x
        local upY = p.tile_y - 1

        local ok, walkable = pcall(function()
            return bot:isWalkable(upX, upY)
        end)

        if ok and walkable then
            pcall(function()
                bot:walk(0, -1)
            end)
            sleep_ms(500)
        else
            log("[" .. botId .. "] Cannot move up for drop step " .. i .. "/" .. stepsUp .. " in " .. saveWorld .. ". Dropping at current tile.")
            return false
        end
    end

    return true
end

local function updateNextDropSpot(saveWorld)
    local nextSteps = (PORTAL_DROP_STEPS[saveWorld] or 0) + 1

    if nextSteps > MAX_DROP_UP_STEPS then
        nextSteps = 0
    end

    PORTAL_DROP_STEPS[saveWorld] = nextSteps
end

local function dropButterfliesAtSaveWorld(bot, botId, countStats)
    local beforeDrop = countButterflies(bot)

    if beforeDrop <= 0 then
        log(string.format("[%s] No butterflies to store.", botId))
        return
    end

    local saveWorld = getRandomSaveWorld()
    local saveWorldBase = string.lower(tostring(saveWorld):match("^([^:]+)") or tostring(saveWorld))

    STATS.last_storage_world = saveWorld
    STATS.last_update = "[" .. botId .. "] going to storage " .. saveWorld .. " with " .. beforeDrop .. " butterfly items"
    sendStatsWebhook(false)

    log(string.format("[%s] 🚚 Going to storage world: %s", botId, saveWorld))

    local enteredStorage = false

    for warpAttempt = 1, 8 do
        if not bot:connected() then
            bot:set_auto_reconnect(true)
            pcall(function()
                bot:connect()
            end)
            sleep_ms(RECONNECT_WAIT_MS)
        end

        pcall(function()
            bot:warp(saveWorld)
        end)

        local warpStart = now_ms()

        while now_ms() - warpStart < 30000 do
            if bot:state() == "InWorld" then
                local currentWorld = bot:get_world_name()
                local currentWorldBase = currentWorld and string.lower(tostring(currentWorld)) or ""

                if currentWorldBase == saveWorldBase or currentWorldBase == string.lower(tostring(saveWorld)) then
                    enteredStorage = true
                    break
                end
            end

            if not bot:connected() then
                pcall(function()
                    bot:connect()
                end)
                sleep_ms(RECONNECT_WAIT_MS)
            end

            sleep_ms(500)
        end

        if enteredStorage then
            log(string.format("[%s] ✅ Entered storage world %s", botId, saveWorld))
            break
        end

        log(string.format("[%s] Still not confirmed in storage. Retrying warp (%d/8)...", botId, warpAttempt))
        sleep_ms(2000)
    end

    if not enteredStorage then
        STATS.last_update = "[" .. botId .. "] failed to enter storage " .. saveWorld
        sendStatsWebhook(false)
        log(string.format("[%s] ❌ Could not confirm storage world %s. Skipping drop for now.", botId, saveWorld))
        return
    end

    sleep_ms(2500)

    if USE_STORAGE_POSITION then
        local ok, err = pcall(function()
            bot:find_path(STORAGE_DROP_X, STORAGE_DROP_Y)
        end)

        if not ok then
            STATS.failed_paths = STATS.failed_paths + 1
            log(string.format("[%s] Failed to path to storage drop tile: %s", botId, tostring(err)))
        end

        sleep_ms(800)
    end

    moveDropSpotForPortal(bot, botId, saveWorld)
    sleep_ms(500)

    local totalDropped = 0

    for dropAttempt = 1, 2 do
        local items = readInventorySafe(bot, 5)

        if not items then
            log(string.format("[%s] Could not read inventory before drop attempt %d/2", botId, dropAttempt))
            sleep_ms(1000)
        else
            local foundAny = false
            local droppedThisAttempt = 0

            for _, item in ipairs(items) do
                if isButterflyInventoryItem(item) and item.amount and item.amount > 0 then
                    foundAny = true
                    local confirmedDropped = dropOneButterflyItem(bot, botId, item)
                    droppedThisAttempt = droppedThisAttempt + confirmedDropped

                    if countStats and confirmedDropped > 0 then

                        STATS.last_update = "[" .. botId .. "] confirmed " .. confirmedDropped .. "x " .. formatButterflyLabel(item.id) .. " stored"
                    end

                    sleep_ms(500)
                end
            end

            totalDropped = totalDropped + droppedThisAttempt

            if not foundAny then
                log(string.format("[%s] Inventory already clean. No butterfly items found.", botId))
                break
            end

            sleep_ms(1500)

            if not hasButterfly(bot) then
                log(string.format("[%s] ✅ Inventory clean after drop attempt %d/2.", botId, dropAttempt))
                break
            end

            if droppedThisAttempt <= 0 then
                log(string.format("[%s] ⚠️ Attempt %d/2 found butterfly items but confirmed 0 drops.", botId, dropAttempt))
            else
                log(string.format("[%s] Still has butterflies after dropping %d item(s). Attempt %d/2.", botId, droppedThisAttempt, dropAttempt))
            end
        end

        sleep_ms(800)
    end

    local remaining = countButterflies(bot)

    if remaining > 0 then
        STATS.last_update = "[" .. botId .. "] storage drop incomplete: dropped " .. totalDropped .. ", remaining " .. remaining .. " in " .. saveWorld
        log(string.format("[%s] ⚠️ Drop incomplete. Dropped %d, remaining %d in inventory. Next drop spot will NOT move up.", botId, totalDropped, remaining))
    else
        STATS.storage_saves = STATS.storage_saves + 1
        STATS.items_saved = (STATS.items_saved or 0) + totalDropped
        STATS.last_update = "[" .. botId .. "] stored " .. totalDropped .. " butterfly items in " .. saveWorld
        log(string.format("[%s] 📦 Storage complete. Confirmed dropped %d items in %s.", botId, totalDropped, saveWorld))

        if totalDropped > 0 then
            updateNextDropSpot(saveWorld)
            log(string.format("[%s] Next drop offset for %s is now %d tile(s) up.", botId, saveWorld, getPortalDropSteps(saveWorld)))
        else
            log(string.format("[%s] Confirmed inventory clean but dropped 0. Next drop spot will NOT move up.", botId))
        end
    end

    STATS.last_storage_world = saveWorld
    sendStatsWebhook(false)
end

local function initialInventoryCleanup(botIds)
    for _, id in ipairs(botIds) do
        local bot = getBot(id)

        if bot and bot:connected() then
            if hasButterfly(bot) then
                log("[" .. id .. "] Found butterflies in inventory at start. Dropping first...")
                dropButterfliesAtSaveWorld(bot, id, false)
            else
                log("[" .. id .. "] Inventory clean.")
            end
        end

        sleep_ms(500)
    end
end


local function findButterflies(bot)
    local found = {}

    for _, butterflyId in ipairs(BUTTERFLY_IDS) do
        local ok, tiles = pcall(function()
            return bot:findTiles(butterflyId)
        end)

        if ok and tiles and #tiles > 0 then
            for _, pos in ipairs(tiles) do
                local info = getButterflyInfo(butterflyId)
                table.insert(found, {
                    id = butterflyId,
                    name = info.name,
                    rarity = info.rarity,
                    x = pos.x,
                    y = pos.y
                })
            end
        end
    end

    return found
end

local function findCatchableButterflies(bot)
    local found = {}


    for id, _ in pairs(BUTTERFLY_ITEM_LOOKUP) do
        local ok, tiles = pcall(function()
            return bot:findTiles(id)
        end)

        if ok and tiles and #tiles > 0 then
            for _, pos in ipairs(tiles) do
                local info = getButterflyInfo(id)
                table.insert(found, {
                    id = id,
                    name = info.name,
                    rarity = info.rarity,
                    x = pos.x,
                    y = pos.y
                })
            end
        end
    end

    table.sort(found, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)

    return found
end

local function waitForSpawn(bot, botId, world)
    local monitorStart = now_ms()

    while now_ms() - monitorStart < MONITOR_WORLD_MS do
        if isBotDisconnected(bot) then
            log(string.format("[%s] Disconnected while monitoring. Rejoining %s", botId, world))

            local success = forceReconnectAndRejoin(bot, botId, world)
            if not success then
                return {}
            end
        end

        local butterflies = findButterflies(bot)

        if #butterflies > 0 then
            STATS.spawn_found = STATS.spawn_found + 1
            local first = butterflies[1]
            STATS.last_update = "[" .. botId .. "] spawn found in " .. world .. " | " .. formatButterflyLabel(first.id) .. " | Total tiles: " .. #butterflies
            log(string.format("[%s] Spawn found: %s in %s at %d,%d", botId, formatButterflyLabel(first.id), world, first.x, first.y))
            sendStatsWebhook(false)

            return butterflies
        end

        sendStatsWebhook(false)
        sleep_ms(SCAN_INTERVAL_MS)
    end

    return {}
end

local function getButterflyStandCandidates(x, y)

    return {
        {x = x,     y = y + 1}, 
        {x = x + 1, y = y},    
        {x = x - 1, y = y},    
        {x = x,     y = y - 1},
    }
end

local function waitUntilAtTile(bot, x, y, timeoutMs)
    local started = now_ms()

    while now_ms() - started < timeoutMs do
        if not bot:connected() then
            return false
        end

        local ok, pos = pcall(function()
            return bot:pos()
        end)

        if ok and pos and pos.tile_x == x and pos.tile_y == y then
            return true
        end

        sleep_ms(150)
    end

    return false
end

local function moveNearButterfly(bot, botId, butterfly)
    local candidates = getButterflyStandCandidates(butterfly.x, butterfly.y)

    for _, tile in ipairs(candidates) do
        local walkableOk, walkable = pcall(function()
            return bot:isWalkable(tile.x, tile.y)
        end)

        if walkableOk and walkable then
            local startOk = pcall(function()
                bot:start_path(tile.x, tile.y)
            end)

            if startOk then
                if waitUntilAtTile(bot, tile.x, tile.y, PATH_TO_BUTTERFLY_TIMEOUT_MS) then
                    return true, tile.x, tile.y
                end
            end
        end
    end

    STATS.failed_paths = STATS.failed_paths + 1
    STATS.last_update = "[" .. botId .. "] no reachable stand tile near butterfly at " .. butterfly.x .. "," .. butterfly.y
    sendStatsWebhook(false)

    log(string.format("[%s] ⚠️ No reachable walkable tile near butterfly at (%d,%d). Skipping.", botId, butterfly.x, butterfly.y))
    return false, nil, nil
end

local function collectAroundButterfly(bot, butterfly, standX, standY)
    local points = {
        {x = butterfly.x,     y = butterfly.y},
        {x = butterfly.x,     y = butterfly.y + 1},
        {x = butterfly.x + 1, y = butterfly.y},
        {x = butterfly.x - 1, y = butterfly.y},
        {x = butterfly.x,     y = butterfly.y - 1},
    }

    if standX and standY then
        table.insert(points, {x = standX, y = standY})
    end

    for _, p in ipairs(points) do
        pcall(function()
            bot:collect_at(p.x, p.y)
        end)
        sleep_ms(80)
    end

    pcall(function()
        bot:collectAll()
    end)
end

local function debugInventory(bot, botId)
    local ok, items = pcall(function()
        return bot:get_inventory()
    end)

    if not ok or not items then
        log("[" .. botId .. "] Inventory debug failed: cannot read inventory.")
        return
    end

    log("[" .. botId .. "] Inventory debug after butterfly break:")

    local shown = 0
    for _, item in ipairs(items) do
        if item.amount and item.amount > 0 then
            shown = shown + 1
            local known = getButterflyInfo(item.id)
            local displayName = item.name or known.name or "unknown"
            local rarityText = BUTTERFLY_LOOKUP[item.id] and (" [" .. known.rarity .. "]") or ""
            log(
                "[" .. botId .. "] Item:",
                item.id,
                displayName .. rarityText,
                "x" .. tostring(item.amount),
                "type:",
                tostring(item.inventory_type)
            )

            if shown >= 30 then
                log("[" .. botId .. "] Inventory debug stopped after 30 visible stacks.")
                break
            end
        end
    end
end

local function breakButterfly(bot, botId, butterfly, farmWorld)
    if isBotDisconnected(bot) then
        local success = forceReconnectAndRejoin(bot, botId, farmWorld)
        if not success then return false end
    end

    local moved, standX, standY = moveNearButterfly(bot, botId, butterfly)

    if not moved then
        return false
    end

    sleep_ms(AFTER_PATH_DELAY_MS)

    pcall(function()
        bot:set_auto_collect(true, AUTO_COLLECT_INTERVAL_MS)
    end)

    sleep_ms(500)

    for hit = 1, BREAK_HITS do
        if isBotDisconnected(bot) then
            local success = forceReconnectAndRejoin(bot, botId, farmWorld)
            if not success then return false end

            local retryMoved = false
            retryMoved, standX, standY = moveNearButterfly(bot, botId, butterfly)

            if not retryMoved then
                return false
            end

            sleep_ms(AFTER_PATH_DELAY_MS)
        end

        local hitOk, hitErr = pcall(function()
            bot:hit_block_at(butterfly.x, butterfly.y)
        end)

        if not hitOk then
            log(string.format("[%s] hit_block_at error on %s: %s", botId, formatButterflyLabel(butterfly.id), tostring(hitErr)))
        end

        sleep_ms(HIT_DELAY_MS)

        local stateAfterHit = bot:state()
        if stateAfterHit == "Failed" or stateAfterHit == "Disconnected" or stateAfterHit == "Unknown" then
            log(string.format("⚠️ [%s] Bot became %s after hit %d/%d on %s. Stopping hit loop and recovering.", botId, tostring(stateAfterHit), hit, BREAK_HITS, formatButterflyLabel(butterfly.id)))
            hardRecoverBot(bot, botId, farmWorld, "butterfly hit")
            return true
        end
    end

    if bot:state() == "InWorld" then
        collectAroundButterfly(bot, butterfly, standX, standY)
        sleep_ms(1000)
        collectAroundButterfly(bot, butterfly, standX, standY)
    end

    pcall(function()
        bot:set_auto_collect(false)
    end)

    sleep_ms(500)

    STATS.last_update =
        "[" .. botId .. "] broke/hit " ..
        formatButterflyLabel(butterfly.id) ..
        " in " ..
        farmWorld ..
        " at " ..
        butterfly.x ..
        "," ..
        butterfly.y ..
        " from " ..
        tostring(standX) ..
        "," ..
        tostring(standY)

    log(string.format("[%s] Finished hitting %s in %s.", botId, formatButterflyLabel(butterfly.id), farmWorld))
    sendStatsWebhook(false)

    return true
end

local function farmButterflies(bot, botId, farmWorld, butterflies)
    log(string.format("[%s] 🦋 Farming %d butterfly tile(s) in %s", botId, #butterflies, farmWorld))

    for _, b in ipairs(butterflies) do
        log(string.format("[%s] Target: %s at %d,%d", botId, formatButterflyLabel(b.id), b.x, b.y))
    end

    local broken = 0
    local openedSpawnBlock = false

    for _, butterfly in ipairs(butterflies) do
        if isButterflyBlockId(butterfly.id) then
            openedSpawnBlock = true
        end

        local success = breakButterfly(bot, botId, butterfly, farmWorld)

        if success then
            broken = broken + 1
        end

        sleep_ms(300)
    end

    if openedSpawnBlock then
        for wave = 1, 5 do
            sleep_ms(2000)

            local revealed = findCatchableButterflies(bot)

            if #revealed <= 0 then
                log(string.format("[%s] No revealed obtainable butterfly item tiles yet after opening block. Wave %d/5", botId, wave))
            else
                log(string.format("[%s] Found %d revealed obtainable butterfly item tile(s) after opening block. Wave %d/5", botId, #revealed, wave))

                for _, target in ipairs(revealed) do
                    -- Safety: never re-target 1685-1688 here. Only catchable item IDs.
                    if not isButterflyBlockId(target.id) then
                        log(string.format("[%s] Revealed target: %s at %d,%d", botId, formatButterflyLabel(target.id), target.x, target.y))

                        local success = breakButterfly(bot, botId, target, farmWorld)
                        if success then
                            broken = broken + 1
                        end

                        sleep_ms(300)
                    end
                end
            end
        end
    end

    return broken
end


local function runBotCycle(bot, botId)
    bot:set_auto_reconnect(true)

    while true do
        local randomWorld = generateRandomWorld()

        STATS.worlds_checked = STATS.worlds_checked + 1
        STATS.last_update = "[" .. botId .. "] warping to random world " .. randomWorld
        sendStatsWebhook(false)

        log(string.format("[%s] 🌍 Warping to random world: %s", botId, randomWorld))

        local entered = warpAndWait(bot, botId, randomWorld)

        if entered then
            log(string.format("[%s] ✅ Entered %s. Waiting for butterfly spawn.", botId, randomWorld))

            local butterflies = waitForSpawn(bot, botId, randomWorld)

            if #butterflies > 0 then
                log(string.format("[%s] 🟢 Butterfly spawn detected in %s", botId, randomWorld))

                local beforeFarmItems = getInventorySnapshot(bot)
                local broken = farmButterflies(bot, botId, randomWorld, butterflies)

                if broken > 0 then
                    recoverIfFailed(bot, botId, randomWorld, "after butterfly farming")

                    if bot:state() == "InWorld" then
                        pcall(function()
                            bot:set_auto_collect(true, AUTO_COLLECT_INTERVAL_MS)
                        end)

                        sleep_ms(AUTO_COLLECT_AFTER_BREAK_MS)

                        pcall(function()
                            bot:set_auto_collect(false)
                        end)
                    else
                        log(string.format("[%s] Not InWorld after farming recovery. Skipping extra collect and checking inventory.", botId))
                    end

                    local gained, afterFarmItems = recordInventoryGainsWithRetry(bot, beforeFarmItems, botId, 3, 2000)
                    local hasButterflyAfterFetch = snapshotHasButterflyItems(afterFarmItems) or hasButterfly(bot)

                    if hasButterflyAfterFetch then
                        log(string.format("[%s] Butterfly item confirmed after farming. Moving to storage.", botId))
                        dropButterfliesAtSaveWorld(bot, botId, false)
                    else
                        log(string.format("[%s] No butterfly items in inventory after 3 fetches. Inventory gained: %d", botId, gained))
                        debugInventory(bot, botId)
                        STATS.last_update = "[" .. botId .. "] broke butterfly but no item found after 3 inventory fetches"
                        sendStatsWebhook(false)
                    end
                else
                    log(string.format("[%s] Spawn found but failed to break any butterfly.", botId))
                end
            else
                log(string.format("[%s] No butterfly spawn in %s . Moving to another world.", botId, randomWorld))
            end
        else
            log(string.format("[%s] Failed to enter %s. Trying another world...", botId, randomWorld))
            sleep_ms(2000)
        end

        sleep_ms(2000)
    end
end


math.randomseed(now_ms())

local botIds = getBots()

if #botIds == 0 then
    log("❌ No active bots found.")
    return
end

STATS.current_bots = #botIds
STATS.last_update = "Script started for " .. #botIds .. " bot(s)"

log(string.format("🚀 Butterfly Hunter started for %d bot(s).", #botIds))

updatePricesIfNeeded(true)
sendStatsWebhook(true)

initialInventoryCleanup(botIds)

local function startBotThread(bot, botId)
    local function threadBody()
        while true do
            local ok, err = pcall(function()
                runBotCycle(bot, botId)
            end)

            log(string.format("❌ Thread error [%s]: %s", botId, tostring(err)))
            STATS.last_update = "[" .. botId .. "] thread error: " .. tostring(err)
            sendStatsWebhook(true)

            sleep_ms(3000)
        end
    end

    if type(runThread) == "function" then
        runThread(threadBody)
        log(string.format("[%s] Thread started.", botId))
    else
        log(string.format("[%s] runThread not found; using coroutine fallback.", botId))
        coroutine.wrap(threadBody)()
    end
end

for _, id in ipairs(botIds) do
    local bot = getBot(id)

    if bot then
        bot:set_auto_reconnect(true)
        startBotThread(bot, id)
        sleep_ms(BOT_START_DELAY_MS)
    else
        log(string.format("⚠️ Bot %s not found, skipping.", id))
    end
end

while true do
    sendStatsWebhook(false)
    sleep_ms(60000)
end
