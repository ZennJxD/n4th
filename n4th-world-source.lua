-- Baca metadata fungsi dan cuplikan source client. Tidak memanggil remote game.
local output = {}
local function emit(text) output[#output + 1] = tostring(text) end
local globals = (getgenv and getgenv()) or _G
local session = globals.__n4thOpus
local refs = session and session.References or {}
local constants = (debug and debug.getconstants) or getconstants
local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
emit("n4th world API/source v1 | Place=" .. tostring(game.PlaceId) .. " | Version=" .. tostring(game.PlaceVersion))
emit("Queue=" .. type(queue) .. " | decompile=" .. type(decompile) .. " | constants=" .. type(constants))

local function keys(value)
    if type(value) ~= "table" then return type(value) end
    local list = {}
    for key, item in pairs(value) do
        if type(key) == "string" then list[#list + 1] = key .. ":" .. type(item) end
    end
    table.sort(list)
    return table.concat(list, ", ")
end

local function describe(label, fn)
    local fields = {}
    if type(constants) == "function" then
        local ok, values = pcall(constants, fn)
        if ok and type(values) == "table" then
            for _, value in pairs(values) do
                if type(value) == "string" and #value < 90 and #fields < 60 then
                    fields[#fields + 1] = value:gsub("\n", " ")
                end
            end
        end
    end
    emit(label .. " constants: " .. table.concat(fields, " | "))
end

local function inspect(label, value)
    emit(label .. " keys: " .. keys(value))
    if type(value) ~= "table" then return end
    for key, fn in pairs(value) do
        if type(key) == "string" and type(fn) == "function" then
            local lower = key:lower()
            if lower:find("world", 1, true) or lower:find("enter", 1, true) or lower:find("pick", 1, true)
                or lower:find("search", 1, true) or lower:find("look", 1, true) or lower == "call" or lower == "ask" then
                describe(label .. "." .. key, fn)
            end
        end
    end
end

inspect("Active World", refs.World)
inspect("Active Menu", refs.Menu)
local replicated = game:GetService("ReplicatedStorage")
local shared = replicated:FindFirstChild("Shared")
local player = game:GetService("Players").LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
local gameGui = playerGui and playerGui:FindFirstChild("GameGui")
local modules = {
    { name = "Net", object = shared and shared:FindFirstChild("Net") },
    { name = "WorldMenu", object = gameGui and gameGui:FindFirstChild("WorldMenu", true) },
}
for _, entry in ipairs(modules) do
    if entry.object and entry.object:IsA("ModuleScript") then
        local ok, value = pcall(require, entry.object)
        if ok then
            inspect(entry.name, value)
            if type(value) == "table" then emit(entry.name .. " EVENTS: " .. keys(rawget(value, "EVENTS"))) end
        else emit(entry.name .. " require failed: " .. tostring(value)) end
        if type(decompile) == "function" then
            local decoded, source = pcall(decompile, entry.object)
            if decoded and type(source) == "string" then
                emit(entry.name .. " source length=" .. #source)
                local lower, count = source:lower(), 0
                for _, term in ipairs({ "worldinfo", "worldlookup", "searchworld", "getworld", "worldlist", "enterworld", "teleport" }) do
                    local index = lower:find(term, 1, true)
                    if index and count < 7 then
                        emit("SOURCE " .. entry.name .. " / " .. term .. "\n" .. source:sub(math.max(1, index - 350), math.min(#source, index + 750)))
                        count += 1
                    end
                end
                if count == 0 then emit("SOURCE " .. entry.name .. " / start\n" .. source:sub(1, 1600)) end
            else emit(entry.name .. " decompile failed: " .. tostring(source)) end
        end
    else emit(entry.name .. " module missing") end
end
local remoteNames = {}
for _, item in ipairs(replicated:GetDescendants()) do
    if (item:IsA("RemoteFunction") or item:IsA("RemoteEvent")) and item.Name:lower():find("world", 1, true) then
        remoteNames[#remoteNames + 1] = item:GetFullName() .. " (" .. item.ClassName .. ")"
    end
end
emit("World remote names: " .. table.concat(remoteNames, ", "))
local report = table.concat(output, "\n")
print(report)
if type(writefile) == "function" then pcall(writefile, "n4th-world-source-report.txt", report) end
if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, report)
    if ok then print("[n4th] Laporan world/source sudah disalin. Paste ke chat ini.") end
end
return report
