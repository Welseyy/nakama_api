if GetCurrentResourceName() ~= "nakama_api" then
    print("Nakama API can only be used named as 'nakama_api'")
    return
end

NakamaAPI = {}
NakamaAPI.__index = NakamaAPI

local cfg = NAKAMA_CONFIG
local protocol = cfg.use_https and "https" or "http"
local NAKAMA_URL = protocol.."://"..cfg.host..":"..cfg.port

local playerCache = {}
local lastRequestTime = 0
local MIN_REQUEST_INTERVAL = 50

local function validateUserId(userId)
    if not userId or type(userId) ~= "string" or userId == "" then
        return false, "Invalid user ID"
    end
    return true
end

local function shouldRateLimit()
    local now = GetGameTimer()
    if now - lastRequestTime < MIN_REQUEST_INTERVAL then
        return true
    end
    lastRequestTime = now
    return false
end

local function post(endpoint, data, timeout)
    timeout = timeout or 5000
    
    if shouldRateLimit() then
        Citizen.Wait(MIN_REQUEST_INTERVAL)
    end

    local responseData = {
        body = nil,
        status = nil,
        headers = nil,
        error = nil
    }

    PerformHttpRequest(
        NAKAMA_URL..endpoint,
        function(status, text, headers)
            responseData.status = status
            responseData.body = text
            responseData.headers = headers
            
            if status == 0 then
                responseData.error = "Connection failed"
            elseif status >= 400 then
                responseData.error = "HTTP "..status
            end
        end,
        "POST",
        json.encode(data),
        {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer "..cfg.server_key
        }
    )

    local elapsed = 0
    local waitInterval = 50
    while responseData.body == nil and elapsed < timeout do
        Citizen.Wait(waitInterval)
        elapsed = elapsed + waitInterval
    end

    if responseData.body == nil then
        return nil, "Request timeout after "..timeout.."ms"
    end

    if responseData.error then
        return nil, responseData.error
    end

    local success, decoded = pcall(json.decode, responseData.body)
    if not success then
        return nil, "Failed to parse response"
    end

    return decoded, nil, responseData.status
end

local function get(endpoint, timeout)
    timeout = timeout or 5000
    
    if shouldRateLimit() then
        Citizen.Wait(MIN_REQUEST_INTERVAL)
    end

    local responseData = {
        body = nil,
        status = nil,
        error = nil
    }

    PerformHttpRequest(
        NAKAMA_URL..endpoint,
        function(status, text, headers)
            responseData.status = status
            responseData.body = text
            
            if status == 0 then
                responseData.error = "Connection failed"
            elseif status >= 400 then
                responseData.error = "HTTP "..status
            end
        end,
        "GET",
        "",
        {["Authorization"] = "Bearer "..cfg.server_key}
    )

    local elapsed = 0
    local waitInterval = 50
    while responseData.body == nil and elapsed < timeout do
        Citizen.Wait(waitInterval)
        elapsed = elapsed + waitInterval
    end

    if responseData.body == nil then
        return nil, "Request timeout"
    end

    if responseData.error then
        return nil, responseData.error
    end

    local success, decoded = pcall(json.decode, responseData.body)
    if not success then
        return nil, "Failed to parse response"
    end

    return decoded, nil
end

function NakamaAPI.authenticate(userId, username, create)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    create = create ~= false

    local payload = {
        id = userId,
        username = username
    }

    local endpoint = "/v2/account/authenticate/custom"
    if create then
        endpoint = endpoint.."?create=true"
    end

    local result, err = post(endpoint, payload)
    
    if result and result.token then
        playerCache[userId] = playerCache[userId] or {}
        playerCache[userId].token = result.token
        playerCache[userId].session = result
    end

    return result, err
end

function NakamaAPI.getAccount(userId)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if playerCache[userId] and playerCache[userId].account then
        local cacheAge = os.time() - (playerCache[userId].accountTimestamp or 0)
        if cacheAge < 300 then
            return playerCache[userId].account
        end
    end

    local result, err = get("/v2/account?user_id="..userId)
    
    if result then
        playerCache[userId] = playerCache[userId] or {}
        playerCache[userId].account = result
        playerCache[userId].accountTimestamp = os.time()
    end

    return result, err
end

function NakamaAPI.updateAccount(userId, displayName, avatarUrl, langTag, location, timezone)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    local payload = {}
    
    if displayName then payload.display_name = displayName end
    if avatarUrl then payload.avatar_url = avatarUrl end
    if langTag then payload.lang_tag = langTag end
    if location then payload.location = location end
    if timezone then payload.timezone = timezone end

    local result, err = post("/v2/account", payload)
    
    if result then
        if playerCache[userId] then
            playerCache[userId].account = nil
            playerCache[userId].accountTimestamp = nil
        end
    end

    return result, err
end

function NakamaAPI.storageRead(userId, collection, keys)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not keys or #keys == 0 then
        return nil, "No keys provided"
    end

    local cacheKey = collection..":"..table.concat(keys, ",")
    
    if playerCache[userId] and playerCache[userId].storage and playerCache[userId].storage[cacheKey] then
        local cacheAge = os.time() - (playerCache[userId].storage[cacheKey].timestamp or 0)
        if cacheAge < 60 then
            return playerCache[userId].storage[cacheKey].data
        end
    end

    local objectIds = {}
    for _, key in ipairs(keys) do
        table.insert(objectIds, "collection="..collection.."&key="..key.."&user_id="..userId)
    end

    local endpoint = "/v2/storage?"..table.concat(objectIds, "&")
    local result, err = get(endpoint)
    
    if result and result.objects then
        playerCache[userId] = playerCache[userId] or {}
        playerCache[userId].storage = playerCache[userId].storage or {}
        playerCache[userId].storage[cacheKey] = {
            data = result,
            timestamp = os.time()
        }
    end

    return result, err
end

function NakamaAPI.storageWrite(userId, collection, data)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not data or type(data) ~= "table" then
        return nil, "Invalid data provided"
    end

    local objects = {}
    for key, value in pairs(data) do
        table.insert(objects, {
            collection = collection,
            key = key,
            value = json.encode(value),
            user_id = userId,
            permission_read = 1,
            permission_write = 0
        })
    end

    local payload = {objects = objects}
    local result, err = post("/v2/storage", payload)
    
    if result then
        if playerCache[userId] and playerCache[userId].storage then
            playerCache[userId].storage = {}
        end
    end

    return result, err
end

function NakamaAPI.storageDelete(userId, collection, keys)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not keys or #keys == 0 then
        return nil, "No keys provided"
    end

    local objectIds = {}
    for _, key in ipairs(keys) do
        table.insert(objectIds, {
            collection = collection,
            key = key,
            user_id = userId
        })
    end

    local payload = {object_ids = objectIds}
    local result, err = post("/v2/storage/delete", payload)
    
    if result then
        if playerCache[userId] and playerCache[userId].storage then
            playerCache[userId].storage = {}
        end
    end

    return result, err
end

function NakamaAPI.leaderboardWrite(leaderboardId, userId, score, subscore, metadata)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not leaderboardId or leaderboardId == "" then
        return nil, "Invalid leaderboard ID"
    end

    local payload = {
        leaderboard_records = {{
            leaderboard_id = leaderboardId,
            user_id = userId,
            score = score,
            subscore = subscore or 0,
            metadata = metadata or {}
        }}
    }

    return post("/v2/leaderboard/"..leaderboardId, payload)
end

function NakamaAPI.leaderboardList(leaderboardId, ownerIds, limit, cursor)
    if not leaderboardId or leaderboardId == "" then
        return nil, "Invalid leaderboard ID"
    end

    local query = "?limit="..(limit or 10)
    
    if ownerIds and #ownerIds > 0 then
        for _, ownerId in ipairs(ownerIds) do
            query = query.."&owner_ids="..ownerId
        end
    end
    
    if cursor then
        query = query.."&cursor="..cursor
    end

    return get("/v2/leaderboard/"..leaderboardId..query)
end

function NakamaAPI.leaderboardRecordsAroundOwner(leaderboardId, userId, limit)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not leaderboardId or leaderboardId == "" then
        return nil, "Invalid leaderboard ID"
    end

    return get("/v2/leaderboard/"..leaderboardId.."/owner/"..userId.."?limit="..(limit or 10))
end

function NakamaAPI.matchCreate(userId)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    return post("/v2/match", {})
end

function NakamaAPI.matchList(limit, authoritative, label, minSize, maxSize)
    local query = "?limit="..(limit or 10)
    
    if authoritative ~= nil then
        query = query.."&authoritative="..tostring(authoritative)
    end
    if label then
        query = query.."&label="..label
    end
    if minSize then
        query = query.."&min_size="..minSize
    end
    if maxSize then
        query = query.."&max_size="..maxSize
    end

    return get("/v2/match"..query)
end

function NakamaAPI.friendsList(userId, limit, state, cursor)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if playerCache[userId] and playerCache[userId].friends then
        local cacheAge = os.time() - (playerCache[userId].friendsTimestamp or 0)
        if cacheAge < 120 then
            return playerCache[userId].friends
        end
    end

    local query = "?limit="..(limit or 100)
    if state then query = query.."&state="..state end
    if cursor then query = query.."&cursor="..cursor end

    local result, err = get("/v2/friend"..query)
    
    if result then
        playerCache[userId] = playerCache[userId] or {}
        playerCache[userId].friends = result
        playerCache[userId].friendsTimestamp = os.time()
    end

    return result, err
end

function NakamaAPI.friendsAdd(userId, friendUserIds)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not friendUserIds or #friendUserIds == 0 then
        return nil, "No friend IDs provided"
    end

    local payload = {ids = friendUserIds}
    local result, err = post("/v2/friend", payload)
    
    if result and playerCache[userId] then
        playerCache[userId].friends = nil
        playerCache[userId].friendsTimestamp = nil
    end

    return result, err
end

function NakamaAPI.friendsDelete(userId, friendUserIds)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not friendUserIds or #friendUserIds == 0 then
        return nil, "No friend IDs provided"
    end

    local payload = {ids = friendUserIds}
    local result, err = post("/v2/friend/delete", payload)
    
    if result and playerCache[userId] then
        playerCache[userId].friends = nil
        playerCache[userId].friendsTimestamp = nil
    end

    return result, err
end

function NakamaAPI.groupCreate(userId, name, description, avatarUrl, langTag, open, maxCount)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not name or name == "" then
        return nil, "Group name is required"
    end

    local payload = {
        name = name,
        description = description or "",
        avatar_url = avatarUrl or "",
        lang_tag = langTag or "en",
        open = open ~= false,
        max_count = maxCount or 100
    }

    return post("/v2/group", payload)
end

function NakamaAPI.groupsList(userId, limit, cursor)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    local query = "?limit="..(limit or 20)
    if cursor then query = query.."&cursor="..cursor end

    return get("/v2/user/"..userId.."/group"..query)
end

function NakamaAPI.groupJoin(groupId, userId)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not groupId or groupId == "" then
        return nil, "Invalid group ID"
    end

    return post("/v2/group/"..groupId.."/join", {})
end

function NakamaAPI.groupLeave(groupId, userId)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not groupId or groupId == "" then
        return nil, "Invalid group ID"
    end

    return post("/v2/group/"..groupId.."/leave", {})
end

function NakamaAPI.notificationsList(userId, limit, cacheableCursor)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    local query = "?limit="..(limit or 100)
    if cacheableCursor then
        query = query.."&cacheable_cursor="..cacheableCursor
    end

    return get("/v2/notification"..query)
end

function NakamaAPI.notificationsDelete(userId, notificationIds)
    local valid, err = validateUserId(userId)
    if not valid then return nil, err end

    if not notificationIds or #notificationIds == 0 then
        return nil, "No notification IDs provided"
    end

    local payload = {ids = notificationIds}
    return post("/v2/notification/delete", payload)
end

function NakamaAPI.rpcCall(rpcId, payload, userId)
    if not rpcId or rpcId == "" then
        return nil, "Invalid RPC ID"
    end

    local data = {
        id = rpcId,
        payload = json.encode(payload or {})
    }
    
    if userId then
        data.http_key = userId
    end

    return post("/v2/rpc/"..rpcId, data)
end

function NakamaAPI.getCachedData(userId, dataType)
    if not playerCache[userId] then return nil end
    return playerCache[userId][dataType]
end

function NakamaAPI.clearCache(userId)
    if userId then
        playerCache[userId] = nil
    else
        playerCache = {}
    end
end

function NakamaAPI.healthCheck()
    local result, err = get("/healthcheck")
    return result ~= nil, err
end

function NakamaAPI.getCacheStats()
    local count = 0
    local totalSize = 0
    
    for userId, data in pairs(playerCache) do
        count = count + 1
        for key, value in pairs(data) do
            if type(value) == "table" then
                totalSize = totalSize + 1
            end
        end
    end
    
    return {
        users = count,
        entries = totalSize
    }
end

RegisterCommand("nakama_status", function(source)
    if source == 0 then
        local stats = NakamaAPI.getCacheStats()
        local healthy, err = NakamaAPI.healthCheck()
        
        print("^2Nakama API Status^7")
        print("Health: "..(healthy and "^2Connected^7" or "^1Failed^7 - "..(err or "unknown")))
        print("Cache: "..stats.users.." users, "..stats.entries.." entries")
    end
end, false)

function NakamaAPI.getUserIdFromSource(src)
    local identifiers = GetPlayerIdentifiers(src)
    
    if not identifiers or #identifiers == 0 then
        return nil, "No identifiers found"
    end
    
    for _, identifier in ipairs(identifiers) do
        if string.match(identifier, "^license:") then
            return identifier, nil
        end
    end
    
    return nil, "No license identifier found"
end

AddEventHandler("playerDropped", function(reason)
    local src = source
    local userId, err = NakamaAPI.getUserIdFromSource(src)
    
    if userId then
        NakamaAPI.clearCache(userId)
    end
end)

local function wrapForExport(func)
    return function(...)
        local result, err = func(...)
        return {
            success = result ~= nil and err == nil,
            data = result,
            error = err
        }
    end
end

exports('authenticate', wrapForExport(NakamaAPI.authenticate))
exports('getAccount', wrapForExport(NakamaAPI.getAccount))
exports('updateAccount', wrapForExport(NakamaAPI.updateAccount))
exports('storageRead', wrapForExport(NakamaAPI.storageRead))
exports('storageWrite', wrapForExport(NakamaAPI.storageWrite))
exports('storageDelete', wrapForExport(NakamaAPI.storageDelete))
exports('leaderboardWrite', wrapForExport(NakamaAPI.leaderboardWrite))
exports('leaderboardList', wrapForExport(NakamaAPI.leaderboardList))
exports('leaderboardRecordsAroundOwner', wrapForExport(NakamaAPI.leaderboardRecordsAroundOwner))
exports('matchCreate', wrapForExport(NakamaAPI.matchCreate))
exports('matchList', wrapForExport(NakamaAPI.matchList))
exports('friendsList', wrapForExport(NakamaAPI.friendsList))
exports('friendsAdd', wrapForExport(NakamaAPI.friendsAdd))
exports('friendsDelete', wrapForExport(NakamaAPI.friendsDelete))
exports('groupCreate', wrapForExport(NakamaAPI.groupCreate))
exports('groupsList', wrapForExport(NakamaAPI.groupsList))
exports('groupJoin', wrapForExport(NakamaAPI.groupJoin))
exports('groupLeave', wrapForExport(NakamaAPI.groupLeave))
exports('notificationsList', wrapForExport(NakamaAPI.notificationsList))
exports('notificationsDelete', wrapForExport(NakamaAPI.notificationsDelete))
exports('rpcCall', wrapForExport(NakamaAPI.rpcCall))
exports('getUserIdFromSource', wrapForExport(NakamaAPI.getUserIdFromSource))
exports('getCachedData', NakamaAPI.getCachedData)
exports('clearCache', NakamaAPI.clearCache)
exports('healthCheck', NakamaAPI.healthCheck)
exports('getCacheStats', NakamaAPI.getCacheStats)

return NakamaAPI