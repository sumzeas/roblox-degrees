local sqlite3       = require "lsqlite3"
local socket        = require "socket"
local Utils         = require "utils"

---@class SocialNetwork
---@field private users { [number]: RobloxUser }
---@field private nameMap { [string]: RobloxUser }
---@field private db sqlite3_db
local SocialNetwork = {}
SocialNetwork.__index = SocialNetwork

---@class RobloxUser
---@field id number
---@field username string
---@field friends number[]

---Creates a new SocialNetwork object
---@return SocialNetwork
function SocialNetwork.new()
    local self = setmetatable({
        users       = {},
        nameMap     = {},
        db          = sqlite3.open("social_network.db")
    }, SocialNetwork)

    self:initDb()

    return self
end

---Initializes the database with essential tables
function SocialNetwork:initDb()
    self.db:exec([[
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE
    );
    ]])

    self.db:exec([[
    CREATE TABLE IF NOT EXISTS friendships (
        user_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        CHECK (user_id < friend_id),
        PRIMARY KEY (user_id, friend_id)
    );
    ]])
end

---Stores a user into the database.
---@param user RobloxUser
---@package
function SocialNetwork:storeUserInDb(user)
    self.db:exec(string.format([[
        INSERT OR IGNORE INTO users (id, username)
        VALUES (%d, '%s');
    ]], user.id, user.username))

    for _, friendId in ipairs(user.friends) do
        local a = math.min(user.id, friendId)
        local b = math.max(user.id, friendId)

        self.db:exec(string.format([[
            INSERT OR IGNORE INTO friendships (user_id, friend_id)
            VALUES (%d, %d);
        ]], a, b))
    end
end

---Retrieves friends of userId from the database.
---@param userId number
---@package
function SocialNetwork:getFriendsFromDb(userId)
    local friends = {}

    for row in self.db:nrows(string.format([[
        SELECT
            CASE
                WHEN user_id = %d THEN friend_id
                ELSE user_id
            END AS friend_id
        FROM friendships
        WHERE user_id = %d OR friend_id = %d;
    ]], userId, userId, userId)) do
        table.insert(friends, row.friend_id)
    end

    return friends
end

---Fetches a ROBLOX username from the provided userId.
---Automatically caches the API result if it does not already exist.
---@param userId number
---@return RobloxUser? user
function SocialNetwork:getByUserId(userId)
    -- Making sure userId is not cached before continuing
    if self.users[userId] then
        return self.users[userId]
    end

    -- Checking database before calling API
    local userRow
    for row in self.db:nrows(string.format([[
        SELECT username, id FROM users WHERE id = %d;
    ]], userId)) do
        userRow = row
        break
    end

    if userRow then
        local user = {
            id          = userRow.id,
            username    = userRow.username,
            friends     = self:getFriendsFromDb(userRow.id),
        }

        self.users[user.id] = user
        self.nameMap[string.lower(user.username)] = user

        return user
    end

    -- Fetching user info from API
    local userInfo = self:safeApiCall(Utils.getUserInfoFromUserId, userId)
    if not userInfo then return nil end

    -- Fetching friends from API
    local userFriends = self:safeApiCall(Utils.getFriendsFromUserId, userId)
    if not userFriends then return nil end

    -- Caching result
    ---@type RobloxUser
    local user = {
        username        = userInfo.name,
        id              = userInfo.id,
        friends         = userFriends,
    }

    self.users[userId] = user
    self.nameMap[string.lower(user.username)] = user

    -- Storing in database
    self:storeUserInDb(user)

    return user
end

---Fetches a ROBLOX user from the provided username.
---Automatically caches the API result if it does not already exist.
---@param username string
---@return RobloxUser? user
function SocialNetwork:getByUsername(username)
    username = string.lower(username)
    if self.nameMap[username] then
        return self.nameMap[username]
    end

    -- Checking database before calling API
    local userRow
    for row in self.db:nrows(string.format([[
        SELECT username, id FROM users WHERE username = '%s';
    ]], username)) do
        userRow = row
        break
    end

    if userRow then
        local user = {
            id          = userRow.id,
            username    = userRow.username,
            friends     = self:getFriendsFromDb(userRow.id),
        }

        self.users[userRow.id] = user
        self.nameMap[username] = user

        return user
    end

    -- Fetching user info from API
    local userInfo = self:safeApiCall(Utils.getUserInfoFromUsername, username)
    if not userInfo then return nil end

    -- Fetching user friends from API
    local userFriends = self:safeApiCall(Utils.getFriendsFromUserId, userInfo.id)
    if not userFriends then return nil end

    -- Caching result
    ---@type RobloxUser
    local user = {
        username    = username,
        id          = userInfo.id,
        friends     = userFriends,
    }

    self.users[userInfo.id] = user
    self.nameMap[username] = user

    -- Storing in database
    self:storeUserInDb(user)

    return user
end

---Finds the degrees of seperation between to users given their usernames.
---Exits early if the API fails.
---@param username1 string
---@param username2 string
---@param _opts {
---     MAX_DEPTH: integer,
---     PRINT_INTERVAL: integer }?
---@return string[]? path    # The path between user1 to user2
function SocialNetwork:getSeparation(username1, username2, _opts)
    _opts = _opts or {
        MAX_DEPTH       = 6,
        PRINT_INTERVAL  = 0.5,
    }

    local MAX_DEPTH         = _opts.MAX_DEPTH
    local PRINT_INTERVAL    = _opts.PRINT_INTERVAL

    local user1 = self:getByUsername(username1)
    local user2 = self:getByUsername(username2)

    if not user1 or not user2 then
        return nil
    end

    if user1.id == user2.id then
        return { username1 }
    end


    -- BFS structures
    local queue1 = { user1.id }
    local queue2 = { user2.id }

    local visited1 = { [user1.id] = true }
    local visited2 = { [user2.id] = true }

    local parent1 = {}
    local parent2 = {}

    local depth = 0

    -- Performance stats
    local usersSearched = 0
    local lastPrint     = 0
    local timeStart     = socket.gettime()

    local function elapsed()
        return socket.gettime() - timeStart
    end

    local function printStats()
        local now = elapsed()
        if now - lastPrint < PRINT_INTERVAL then
            return
        end

        lastPrint = now

        Utils.log(string.format(
            "Elapsed: %8.2fs | Searched: %8d | Queued: %8d | Depth: %3d",
            now,
            usersSearched,
            #queue1 + #queue2,
            depth
        ))
    end

    -- Performing bidirectional breadth first search
    while #queue1 > 0 and #queue2 > 0 and depth < MAX_DEPTH do
        depth = depth + 1

        -- Expand from side 1
        local nextQueue1 = {}
        for _, userId in ipairs(queue1) do
            local user = self:getByUserId(userId)

            if not user then
                goto continue_user1
            end

            usersSearched = usersSearched + 1
            printStats()

            for _, friendId in ipairs(user.friends) do
                if not visited1[friendId] then
                    visited1[friendId] = true
                    parent1[friendId] = userId

                    -- Check intersection
                    if visited2[friendId] then
                        return self:buildPath(
                            friendId,
                            parent1,
                            parent2
                        )
                    end

                    table.insert(nextQueue1, friendId)
                end
            end

            ::continue_user1::
        end
        queue1 = nextQueue1

        -- Expand from side 2
        local nextQueue2 = {}
        for _, userId in ipairs(queue2) do
            local user = self:getByUserId(userId)
            if not user then
                goto continue_user2
            end

            usersSearched = usersSearched + 1
            printStats()

            for _, friendId in ipairs(user.friends) do
                if not visited2[friendId] then
                    visited2[friendId] = true
                    parent2[friendId] = userId

                    -- Check intersection
                    if visited1[friendId] then
                        return self:buildPath(
                            friendId,
                            parent1,
                            parent2
                        )
                    end

                    table.insert(nextQueue2, friendId)
                end
            end
            ::continue_user2::
        end
        queue2 = nextQueue2
    end

    -- No path found
    return nil
end

---Calls a function with retry logic, gracefully returning upon failure.
---@generic T
---@param fn fun(...: any): T
---@param ... any
---@return T?
---@package
function SocialNetwork:safeApiCall(fn, ...)
    local retries = 3
    local delay = 1

    for _ = 1, retries do
        local ok, result = pcall(fn, ...)

        if ok and result then
            return result
        end

        -- Handle 429 (rate limit)
        if tostring(result):find("429") then
            -- Exponential backoff
            Utils.sleep(delay)
            delay = delay * 2
        else
            Utils.log("API Error:", result)
            return nil
        end
    end

    Utils.log(string.format("Failed to access API after %d attempts...", retries))
    return nil
end

---Helper function for bidirectional breadth first search that builds a path from the intersectionId.
---@package
function SocialNetwork:buildPath(intersectionId, parent1, parent2)
    local path1 = {}
    local current = intersectionId

    while current do
        table.insert(path1, 1, self:getByUserId(current).username)
        current = parent1[current]
    end

    local path2 = {}
    current = parent2[intersectionId]

    while current do
        table.insert(path2, self:getByUserId(current).username)
        current = parent2[current]
    end

    for _, name in ipairs(path2) do
        table.insert(path1, name)
    end

    return path1
end

return SocialNetwork
