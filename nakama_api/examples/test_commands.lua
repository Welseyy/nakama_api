-- IMPORTANT: ADD NAKAMA TO FXMANIFEST/__RESOURCE
-- server_scripts {
--    '@nakama_api/server.lua',
--     ......
-- }

RegisterCommand("nakama_test_auth", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then
        print("No license found for player "..source..": "..userIdResult.error)
        return
    end
    
    local userId = userIdResult.data
    local username = GetPlayerName(source)
    local result = Nakama.authenticate(userId, username, true)
    
    if result.success then
        print("Player authenticated: "..username)
        print("Token: "..result.data.token)
    else
        print("Authentication failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_account", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local account = Nakama.getAccount(userIdResult.data)
    
    if account.success then
        print("Account info:")
        print(json.encode(account.data, {indent = true}))
    else
        print("Failed to get account: "..account.error)
    end
end, false)

RegisterCommand("nakama_test_update_account", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local displayName = args[1] or "TestPlayer"
    
    local result = Nakama.updateAccount(userIdResult.data, displayName, nil, "en", "USA", "America/New_York")
    
    if result.success then
        print("Account updated for "..displayName)
    else
        print("Update failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_storage_write", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local playerData = {
        level = 25,
        experience = 5000,
        coins = 10000,
        deaths = 5,
        kills = 50,
        playtime = 12000,
        last_login = os.time()
    }
    
    local result = Nakama.storageWrite(userIdResult.data, "player_stats", {
        stats = playerData,
        achievements = {
            first_kill = true,
            level_10 = true,
            rich = false
        }
    })
    
    if result.success then
        print("Data saved for player")
    else
        print("Save failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_storage_read", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.storageRead(userIdResult.data, "player_stats", {"stats", "achievements"})
    
    if result.success and result.data.objects then
        print("Retrieved data:")
        for _, obj in ipairs(result.data.objects) do
            print("Key: "..obj.key)
            local data = json.decode(obj.value)
            print("Value: "..json.encode(data, {indent = true}))
        end
    else
        print("Read failed: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_storage_delete", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.storageDelete(userIdResult.data, "player_stats", {"old_data", "temp_data"})
    
    if result.success then
        print("Data deleted")
    else
        print("Delete failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_leaderboard_write", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local score = tonumber(args[1]) or math.random(100, 10000)
    
    local result = Nakama.leaderboardWrite("kills_leaderboard", userIdResult.data, score, 0, {
        username = GetPlayerName(source),
        timestamp = os.time()
    })
    
    if result.success then
        print("Score added to leaderboard: "..score)
    else
        print("Leaderboard write failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_leaderboard_list", function(source, args)
    local limit = tonumber(args[1]) or 10
    
    local result = Nakama.leaderboardList("kills_leaderboard", {}, limit)
    
    if result.success and result.data.records then
        print("Top "..limit.." players:")
        for i, record in ipairs(result.data.records) do
            print(i..". "..record.username.." - Score: "..record.score)
        end
    else
        print("Failed to get leaderboard: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_leaderboard_around", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.leaderboardRecordsAroundOwner("kills_leaderboard", userIdResult.data, 5)
    
    if result.success and result.data.records then
        print("Your position and surrounding players:")
        for i, record in ipairs(result.data.records) do
            local marker = record.owner_id == userIdResult.data and " <- YOU" or ""
            print(record.rank..". "..record.username.." - "..record.score..marker)
        end
    else
        print("Failed to get leaderboard around owner: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_match_create", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.matchCreate(userIdResult.data)
    
    if result.success then
        print("Match created:")
        print("Match ID: "..result.data.match_id)
    else
        print("Match creation failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_match_list", function(source, args)
    local result = Nakama.matchList(10, true, nil, 1, 10)
    
    if result.success and result.data.matches then
        print("Available matches:")
        for i, match in ipairs(result.data.matches) do
            print(i..". Match ID: "..match.match_id.." - Players: "..match.size)
        end
    else
        print("Failed to get match list: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_friends_list", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.friendsList(userIdResult.data, 100)
    
    if result.success and result.data.friends then
        print("Friends list ("..#result.data.friends.." friends):")
        for i, friend in ipairs(result.data.friends) do
            print(i..". "..friend.user.username.." - State: "..friend.state)
        end
    else
        print("Failed to get friends: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_friends_add", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local friendId = args[1]
    if not friendId then
        print("Usage: /nakama_test_friends_add [friend_user_id]")
        return
    end
    
    local result = Nakama.friendsAdd(userIdResult.data, {friendId})
    
    if result.success then
        print("Friend added: "..friendId)
    else
        print("Failed to add friend: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_friends_delete", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local friendId = args[1]
    if not friendId then
        print("Usage: /nakama_test_friends_delete [friend_user_id]")
        return
    end
    
    local result = Nakama.friendsDelete(userIdResult.data, {friendId})
    
    if result.success then
        print("Friend deleted: "..friendId)
    else
        print("Failed to delete friend: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_group_create", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local groupName = args[1] or "Test Group"
    local description = "A test group created via Nakama API"
    
    local result = Nakama.groupCreate(userIdResult.data, groupName, description, nil, "en", true, 50)
    
    if result.success then
        print("Group created:")
        print("Name: "..result.data.name)
        print("ID: "..result.data.id)
    else
        print("Group creation failed: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_groups_list", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.groupsList(userIdResult.data, 20)
    
    if result.success and result.data.user_groups then
        print("Your groups:")
        for i, group in ipairs(result.data.user_groups) do
            print(i..". "..group.group.name.." - Members: "..group.group.edge_count)
        end
    else
        print("Failed to get groups: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_group_join", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local groupId = args[1]
    if not groupId then
        print("Usage: /nakama_test_group_join [group_id]")
        return
    end
    
    local result = Nakama.groupJoin(groupId, userIdResult.data)
    
    if result.success then
        print("Successfully joined group: "..groupId)
    else
        print("Failed to join group: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_group_leave", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local groupId = args[1]
    if not groupId then
        print("Usage: /nakama_test_group_leave [group_id]")
        return
    end
    
    local result = Nakama.groupLeave(groupId, userIdResult.data)
    
    if result.success then
        print("Successfully left group: "..groupId)
    else
        print("Failed to leave group: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_notifications_list", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local result = Nakama.notificationsList(userIdResult.data, 50)
    
    if result.success and result.data.notifications then
        print("Notifications ("..#result.data.notifications.."):")
        for i, notif in ipairs(result.data.notifications) do
            print(i..". Code: "..notif.code.." - Subject: "..notif.subject)
        end
    else
        print("Failed to get notifications: "..(result.error or "Unknown error"))
    end
end, false)

RegisterCommand("nakama_test_notifications_delete", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local notifId = args[1]
    if not notifId then
        print("Usage: /nakama_test_notifications_delete [notification_id]")
        return
    end
    
    local result = Nakama.notificationsDelete(userIdResult.data, {notifId})
    
    if result.success then
        print("Notification deleted: "..notifId)
    else
        print("Failed to delete notification: "..result.error)
    end
end, false)

RegisterCommand("nakama_test_rpc", function(source, args)
    local userIdResult = Nakama.getUserIdFromSource(source)
    if not userIdResult.success then return end
    
    local rpcId = args[1] or "reward_user"
    local payload = {
        user_id = userIdResult.data,
        reward_type = "coins",
        amount = 1000
    }
    
    local result = Nakama.rpcCall(rpcId, payload, userIdResult.data)
    
    if result.success then
        print("RPC executed:")
        print("Response: "..json.encode(result.data, {indent = true}))
    else
        print("RPC failed: "..result.error)
    end
end, false)

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    deferrals.defer()
    
    local src = source
    local userIdResult = Nakama.getUserIdFromSource(src)
    
    if not userIdResult.success then
        deferrals.done("No license identifier found: "..userIdResult.error)
        return
    end
    
    local userId = userIdResult.data
    
    deferrals.update("Authenticating with Nakama...")
    
    local auth = Nakama.authenticate(userId, name, true)
    
    if not auth.success then
        deferrals.done("Nakama authentication failed: "..auth.error)
        return
    end
    
    deferrals.update("Loading player data...")
    
    local data = Nakama.storageRead(userId, "player_stats", {"stats"})
    
    deferrals.done()
    
    print("Player "..name.." successfully connected to Nakama")
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local userIdResult = Nakama.getUserIdFromSource(src)
    
    if userIdResult.success then
        local userId = userIdResult.data
        print("Saving player data on disconnect...")
        
        Nakama.storageWrite(userId, "player_stats", {
            last_disconnect = os.time(),
            disconnect_reason = reason
        })
        
        print("Cache cleared for "..GetPlayerName(src))
    end
end)