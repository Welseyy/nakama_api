# FiveM Nakama API

A Lua wrapper for the Nakama REST API, designed specifically for FiveM servers. This resource provides easy integration with Nakama backend services, including authentication, storage, leaderboards, matchmaking, friends, groups, and notifications.

## Features

- 🔐 **Authentication** - Custom ID authentication with automatic session management
- 💾 **Storage** - Read, write, and delete player data with automatic caching
- 🏆 **Leaderboards** - Submit scores and retrieve rankings
- 🎮 **Matchmaking** - Create and list matches
- 👥 **Friends System** - Add, remove, and list friends
- 🎭 **Groups** - Create and manage player groups
- 📬 **Notifications** - List and delete user notifications
- ⚡ **RPC Calls** - Execute custom server-side functions
- 🚀 **Built-in Caching** - Reduces API calls and improves performance
- 🔄 **Rate Limiting** - Prevents API spam and ensures stability

## Requirements

- FiveM Server
- [Nakama Server](https://heroiclabs.com/nakama/) (v3.x or higher)
- Lua 5.4 support

## Installation

### 1. Install Nakama Server

Follow the [official Nakama installation guide](https://heroiclabs.com/docs/nakama/getting-started/docker-quickstart/).

For quick Docker setup:
```bash
docker run --name nakama \
  -p 7349:7349 \
  -p 7350:7350 \
  -p 7351:7351 \
  heroiclabs/nakama:3.22.0
```

### 2. Install the FiveM Resource

1. Download or clone this repository
2. Place the `nakama_api` folder in your server's `resources` directory
3. Configure the connection settings in `config.lua`
4. Add `ensure nakama_api` to your `server.cfg`

### 3. Configuration

Edit `config.lua`:

```lua
NAKAMA_CONFIG = {
    host = "127.0.0.1",      -- Nakama server IP
    port = 7350,             -- Nakama HTTP port (default: 7350)
    use_https = false,       -- Set to true for HTTPS connections
    server_key = "defaultkey" -- Your Nakama server key
}
```

⚠️ **Security Note:** Never use the default server key in production! Generate a secure key in your Nakama configuration.

## Usage

### In Your Own Resources

Modify `fxmanifest.lua` for your resource, and add the following above any other script files:

```lua
server_script '@nakama_api/server.lua'
```

### Understanding Export Return Values

All exported functions return a table with three fields:
- `success` (boolean) - Whether the operation succeeded
- `data` - The result data (nil if failed)
- `error` (string) - Error message (nil if successful)

**Example:**
```lua
local result = Nakama.authenticate(userId, username, true)
if result.success then
    print("Token: " .. result.data.token)
else
    print("Error: " .. result.error)
end
```

### Basic Examples

#### Authentication
```lua
local userIdResult = Nakama.getUserIdFromSource(source)
if not userIdResult.success then
    print("Error getting user ID: " .. userIdResult.error)
    return
end

local userId = userIdResult.data
local result = Nakama.authenticate(userId, GetPlayerName(source), true)

if result.success then
    print("Player authenticated with token: " .. result.data.token)
else
    print("Authentication failed: " .. result.error)
end
```

#### Storage - Save Player Data
```lua
local playerData = {
    stats = {
        level = 25,
        experience = 5000,
        coins = 10000
    },
    achievements = {
        first_kill = true,
        level_10 = true
    }
}

local result = Nakama.storageWrite(userId, "player_data", playerData)
if result.success then
    print("Data saved successfully")
else
    print("Save failed: " .. result.error)
end
```

#### Storage - Read Player Data
```lua
local result = Nakama.storageRead(userId, "player_data", {"stats", "achievements"})
if result.success and result.data.objects then
    for _, obj in ipairs(result.data.objects) do
        local data = json.decode(obj.value)
        print("Retrieved " .. obj.key .. ": " .. json.encode(data))
    end
else
    print("Read failed: " .. (result.error or "Unknown error"))
end
```

#### Leaderboards - Submit Score
```lua
local score = 1500
local result = Nakama.leaderboardWrite("kills_leaderboard", userId, score, 0, {
    username = GetPlayerName(source),
    timestamp = os.time()
})

if result.success then
    print("Score submitted to leaderboard")
else
    print("Failed: " .. result.error)
end
```

#### Leaderboards - Get Top Players
```lua
local result = Nakama.leaderboardList("kills_leaderboard", {}, 10)
if result.success and result.data.records then
    for i, record in ipairs(result.data.records) do
        print(i .. ". " .. record.username .. " - " .. record.score)
    end
else
    print("Failed to get leaderboard: " .. (result.error or "Unknown error"))
end
```

#### Friends - Add Friend
```lua
local friendUserId = "license:abc123"
local result = Nakama.friendsAdd(userId, {friendUserId})
if result.success then
    print("Friend added successfully")
else
    print("Failed: " .. result.error)
end
```

#### Groups - Create Group
```lua
local result = Nakama.groupCreate(
    userId,
    "My Awesome Group",
    "A group for awesome players",
    nil,
    "en",
    true,
    50
)

if result.success then
    print("Group created with ID: " .. result.data.id)
else
    print("Failed: " .. result.error)
end
```

## API Reference

All functions return a table: `{success = boolean, data = any, error = string}`

### Authentication

- `Nakama.authenticate(userId, username, create)` - Authenticate a user
  - Returns: `{success, data = {token, ...}, error}`
  
- `Nakama.getAccount(userId)` - Get account information
  - Returns: `{success, data = accountInfo, error}`
  
- `Nakama.updateAccount(userId, displayName, avatarUrl, langTag, location, timezone)` - Update account
  - Returns: `{success, data = updatedAccount, error}`

### Storage

- `Nakama.storageRead(userId, collection, keys)` - Read storage objects
  - Returns: `{success, data = {objects = [...]}, error}`
  
- `Nakama.storageWrite(userId, collection, data)` - Write storage objects
  - Returns: `{success, data = writeResult, error}`
  
- `Nakama.storageDelete(userId, collection, keys)` - Delete storage objects
  - Returns: `{success, data = deleteResult, error}`

### Leaderboards

- `Nakama.leaderboardWrite(leaderboardId, userId, score, subscore, metadata)` - Submit a score
  - Returns: `{success, data = recordInfo, error}`
  
- `Nakama.leaderboardList(leaderboardId, ownerIds, limit, cursor)` - List leaderboard records
  - Returns: `{success, data = {records = [...]}, error}`
  
- `Nakama.leaderboardRecordsAroundOwner(leaderboardId, userId, limit)` - Get records around a user
  - Returns: `{success, data = {records = [...]}, error}`

### Matchmaking

- `Nakama.matchCreate(userId)` - Create a match
  - Returns: `{success, data = {match_id = ...}, error}`
  
- `Nakama.matchList(limit, authoritative, label, minSize, maxSize)` - List available matches
  - Returns: `{success, data = {matches = [...]}, error}`

### Friends

- `Nakama.friendsList(userId, limit, state, cursor)` - List friends
  - Returns: `{success, data = {friends = [...]}, error}`
  
- `Nakama.friendsAdd(userId, friendUserIds)` - Add friends
  - Returns: `{success, data = addResult, error}`
  
- `Nakama.friendsDelete(userId, friendUserIds)` - Remove friends
  - Returns: `{success, data = deleteResult, error}`

### Groups

- `Nakama.groupCreate(userId, name, description, avatarUrl, langTag, open, maxCount)` - Create a group
  - Returns: `{success, data = {id = ..., name = ...}, error}`
  
- `Nakama.groupsList(userId, limit, cursor)` - List user's groups
  - Returns: `{success, data = {user_groups = [...]}, error}`
  
- `Nakama.groupJoin(groupId, userId)` - Join a group
  - Returns: `{success, data = joinResult, error}`
  
- `Nakama.groupLeave(groupId, userId)` - Leave a group
  - Returns: `{success, data = leaveResult, error}`

### Notifications

- `Nakama.notificationsList(userId, limit, cacheableCursor)` - List notifications
  - Returns: `{success, data = {notifications = [...]}, error}`
  
- `Nakama.notificationsDelete(userId, notificationIds)` - Delete notifications
  - Returns: `{success, data = deleteResult, error}`

### RPC

- `Nakama.rpcCall(rpcId, payload, userId)` - Call a custom RPC function
  - Returns: `{success, data = rpcResponse, error}`

### Utility

- `Nakama.getUserIdFromSource(source)` - Get user ID from player source
  - Returns: `{success, data = userId, error}`
  
- `Nakama.getCachedData(userId, dataType)` - Get cached data for a user (direct access)
  
- `Nakama.clearCache(userId)` - Clear cached data for a user (direct access)
  
- `Nakama.healthCheck()` - Check Nakama connection (direct access)
  
- `Nakama.getCacheStats()` - Get cache statistics (direct access)

## Server Commands

- `/nakama_status` - Check Nakama connection status and cache statistics (console only)

## Caching

The API implements intelligent caching to reduce unnecessary API calls:

- **Account data**: Cached for 5 minutes
- **Friends list**: Cached for 2 minutes
- **Storage data**: Cached for 1 minute

Caches are automatically cleared when:
- Data is updated
- Player disconnects

## Error Handling

Always check the `success` field before accessing `data`:

```lua
local result = Nakama.authenticate(userId, username)
if not result.success then
    print("Error: " .. result.error)
    return
end

-- Safe to use result.data here
print("Token: " .. result.data.token)
```

## Performance Considerations

- **Rate Limiting**: Built-in 50ms minimum interval between requests
- **Caching**: Reduces repeated API calls
- **Async Operations**: Uses CitizenWait for non-blocking HTTP requests
- **Automatic Cleanup**: Clears cache when players disconnect

## Troubleshooting

### Connection Failed
- Verify Nakama server is running
- Check host and port in `config.lua`
- Ensure firewall allows connections

### Authentication Errors
- Verify `server_key` matches your Nakama configuration
- Check Nakama logs for detailed error messages

### No User ID Found
- Ensure player has a valid license identifier
- Check FiveM server configuration

## Development & Testing

A comprehensive test suite is included in `examples/test_commands.lua`. You can use these commands to test all API functions:

- `/nakama_test_auth` - Test authentication
- `/nakama_test_storage_write` - Test writing data
- `/nakama_test_storage_read` - Test reading data
- `/nakama_test_leaderboard_write [score]` - Submit a score
- And many more...

See the examples folder for complete implementation examples.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- **Author**: wesleyy.
- **Nakama**: [Heroic Labs](https://heroiclabs.com/)
- **FiveM**: [Cfx.re](https://fivem.net/)

## Links

- [Nakama Documentation](https://heroiclabs.com/docs/)
- [Nakama REST API Reference](https://heroiclabs.com/docs/nakama/server-framework/basics/)
- [FiveM Documentation](https://docs.fivem.net/)

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the Nakama documentation
- Join the FiveM community forums

---

**Note**: This is an unofficial wrapper and is not affiliated with Heroic Labs or Cfx.re.