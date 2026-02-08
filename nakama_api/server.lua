if not IsDuplicityVersion() then
    print("Nakama API can only be used on the server side")
    return
end

local nakama_api = exports.nakama_api
local Nakama = setmetatable(Nakama or {}, {
	__index = function(_, index)
		return function(...)
			return nakama_api[index](nil, ...)
		end
	end
})

_ENV.Nakama = Nakama