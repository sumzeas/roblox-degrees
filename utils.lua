local http      = require "socket.http"
local ltn12     = require "ltn12"
local json      = require "dkjson"

local Utils = {}

---@class RobloxUserInfo
---@field description            string
---@field created                string
---@field isBanned               boolean
---@field externalAppDisplayName string
---@field hasVerifiedBadge       boolean
---@field id                     number
---@field name                   string
---@field displayName            string

---Fetches a ROBLOX userId from the provided username.
---@param username string
---@return RobloxUserInfo userInfo
function Utils.getUserInfoFromUsername(username)
    local url = "https://users.roblox.com/v1/usernames/users"

    local requestBody = json.encode({
        usernames = { username },
        excludeBannedUsers = false,
    })

    local response = {}
    local _, code = http.request {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#requestBody),
        },
        source = ltn12.source.string(requestBody),
        sink = ltn12.sink.table(response),
    }

    assert(code == 200, "Request failed with code " .. tostring(code))

    local body = table.concat(response)
    local data = json.decode(body)

    assert(data and data.data[1], "No id found")
    local userId = data.data[1].id

    return Utils.getUserInfoFromUserId(userId)
end


---Fetches a ROBLOX username from the provided userId.
---@param userId number
---@return RobloxUserInfo userInfo
function Utils.getUserInfoFromUserId(userId)
    local body, code = http.request("https://users.roblox.com/v1/users/" .. tostring(userId))

    assert(code == 200, "Request failed with code " .. tostring(code))

    ---@type RobloxUserInfo
    local userInfo = json.decode(body)

    assert(userInfo, "No RobloxUserInfo found")

    return userInfo
end

---Fetches the ROBLOX friends list from the provided userId.
---@param userId number
---@return number[] friendIds
function Utils.getFriendsFromUserId(userId)
    local body, code = http.request("https://friends.roblox.com/v1/users/" .. tostring(userId) .. "/friends")

    assert(code == 200, "Request failed wth code " .. tostring(code))

    local data = json.decode(body)

    assert(data, "Data is nil")

    local idList = {}
    local friendSchemas = data.data

    for _, friendSchema in ipairs(friendSchemas) do
        local id = friendSchema.id
        if id ~= -1 then
            table.insert(idList, friendSchema.id)
        end
    end

    return idList
end

---Sleeps the program for t seconds.
---@param t number
function Utils.sleep(t)
    os.execute("sleep " .. tostring(t))
end

---Logs to the standard output.
---@param ... string
function Utils.log(...)
    io.write("\r\27[K")
    io.write(table.concat({...}, " "))
    io.flush()
end

return Utils
