-- Pemeriksaan baca-saja: tidak memukul, memasang, atau mengirim remote game.
local lines = {}
local function emit(message) lines[#lines + 1] = tostring(message) end
local function keysOf(value, limit)
    if type(value) ~= "table" then return type(value) end
    local keys = {}
    for key, child in pairs(value) do
        if type(key) == "string" then keys[#keys + 1] = key .. ":" .. type(child) end
    end
    table.sort(keys)
    while #keys > (limit or 45) do table.remove(keys) end
    return table.concat(keys, ", ")
end
local function info(fn, option)
    if debug and type(debug.info) == "function" then
        local ok, result = pcall(debug.info, fn, option)
        if ok then return result end
    end
    return "?"
end
local constants = (debug and debug.getconstants) or getconstants
local function describeFunction(fn)
    local result = "name=" .. tostring(info(fn, "n")) .. " | parameters=" .. tostring(info(fn, "a"))
        .. " | source=" .. tostring(info(fn, "s"))
    if type(constants) == "function" then
        local ok, data = pcall(constants, fn)
        if ok and type(data) == "table" then
            local count, fields = 0, {}
            for _, value in pairs(data) do
                count += 1
                if type(value) == "string" and #value < 50 and value:match("^[%a_][%w_%.]*$") and #fields < 18 then
                    fields[#fields + 1] = value
                end
            end
            result ..= " | constants=" .. count .. " | fields=" .. table.concat(fields, ",")
        else result ..= " | constants failed=" .. tostring(data) end
    end
    return result
end
emit("n4th diagnosis v2 | Place=" .. tostring(game.PlaceId) .. " | Version=" .. tostring(game.PlaceVersion))
emit("API getgc=" .. type(getgc) .. " | constants=" .. type(constants) .. " | getconnections=" .. type(getconnections))

local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
if shared then
    local inventory = shared:FindFirstChild("Inventory", true)
    if inventory and inventory:IsA("ModuleScript") then
        local ok, value = pcall(require, inventory)
        emit("Inventory module=" .. inventory:GetFullName() .. " | require=" .. tostring(ok))
        if ok then
            emit("Inventory module keys: " .. keysOf(value))
            if type(value) == "table" and type(value.new) == "function" then emit("Inventory.new: " .. describeFunction(value.new)) end
        end
    else
        emit("Inventory module: missing")
    end
end

if type(getgc) ~= "function" then
    emit("STOP: executor tidak menyediakan getgc")
else
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then
        emit("STOP: getgc gagal: " .. tostring(objects))
    else
        local worlds, bags, candidates, examined, readable, constantCount = 0, 0, {}, 0, 0, 0
        for index, value in ipairs(objects) do
            if type(value) == "table" then
                local slots = rawget(value, "slots")
                local capacity = rawget(value, "capacity")
                if worlds < 2 and type(rawget(value, "fg")) == "table" and type(rawget(value, "bg")) == "table"
                    and type(rawget(value, "w")) == "number" then
                    worlds += 1
                    emit("World #" .. worlds .. " keys: " .. keysOf(value, 350))
                    for key, fn in pairs(value) do
                        if type(key) == "string" and type(fn) == "function" then
                            local lower = key:lower()
                            if lower:find("tile", 1, true) or lower:find("punch", 1, true)
                                or lower:find("hit", 1, true) or lower:find("backpack", 1, true) then
                                emit("World." .. key .. ": " .. describeFunction(fn))
                            end
                        end
                    end
                    local mt = getmetatable(value)
                    emit("World meta: " .. keysOf(mt))
                    if type(mt) == "table" then emit("World __index: " .. keysOf(rawget(mt, "__index"))) end
                end
                if bags < 6 and (type(slots) == "table" or capacity ~= nil) then
                    local countType, removeType = "?", "?"
                    pcall(function() countType, removeType = type(value.count), type(value.remove) end)
                    if type(slots) == "table" or countType == "function" then
                        bags += 1
                        emit("Inventory candidate #" .. bags .. ": " .. keysOf(value, 65))
                        emit("  slots=" .. type(slots) .. " capacity=" .. type(capacity) .. " count=" .. countType .. " remove=" .. removeType)
                        local mt = getmetatable(value)
                        emit("  meta: " .. keysOf(mt))
                        if type(mt) == "table" then emit("  __index: " .. keysOf(rawget(mt, "__index"))) end
                        if type(slots) == "table" then
                            for _, slot in pairs(slots) do
                                if type(slot) == "table" then emit("  slot keys: " .. keysOf(slot, 20)); break end
                            end
                        end
                    end
                end
            elseif type(value) == "function" and type(constants) == "function" then
                local source = tostring(info(value, "s"))
                local functionName = tostring(info(value, "n")):lower()
                if source:find("GameGui", 1, true) or source:find("PlayerScripts", 1, true)
                    or source:find("ReplicatedStorage", 1, true) or functionName == "punch"
                    or functionName == "settile" or functionName == "hittile" then
                    examined += 1
                    local got, data = pcall(constants, value)
                    if got and type(data) == "table" then
                        readable += 1
                        local marks, score, action = {}, 0, false
                        for _, text in pairs(data) do
                            constantCount += 1
                            if type(text) == "string" then
                                local lower = text:lower()
                                if lower:find("punch", 1, true) or lower:find("crack", 1, true)
                                    or lower:find("harvest", 1, true) or lower:find("placedat", 1, true)
                                    or lower:find("settile", 1, true) or lower:find("vending", 1, true)
                                    or lower == "flips" or lower == "tile" or lower == "handpower" then
                                    score += 1
                                    if lower == "newcrack" or lower == "harvestprovider" or lower == "placedat" or lower == "flips" then action = true end
                                    if #marks < 16 then marks[#marks + 1] = text:sub(1, 100) end
                                end
                            end
                        end
                        if action or score >= 3 or functionName == "punch" or functionName == "settile" or functionName == "hittile" then
                            candidates[#candidates + 1] = {fn=value, source=source, marks=marks, score=score}
                        end
                    end
                end
            end
            if index % 1000 == 0 then task.wait() end
        end
        table.sort(candidates, function(a, b) return a.score > b.score end)
        emit("Scanned=" .. #objects .. " | game functions=" .. examined .. " | constants readable=" .. readable .. " | constant values=" .. constantCount)
        for index = 1, math.min(#candidates, 12) do
            local candidate = candidates[index]
            emit("Action candidate #" .. index .. " name=" .. tostring(info(candidate.fn, "n"))
                .. " | parameters=" .. tostring(info(candidate.fn, "a")) .. " | source=" .. candidate.source)
            emit("  markers: " .. table.concat(candidate.marks, " | "))
        end
    end
end

local report = table.concat(lines, "\n")
print(report)
if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, report)
    if ok then print("[n4th] Laporan diagnosis sudah disalin. Paste ke chat ini.") end
end
return report
