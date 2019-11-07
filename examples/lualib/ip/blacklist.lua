local redis = require "db.redis"

local M = {}
function M.add(ip)
    redis.sadd("blacklist", ip)
end

function M.remove(ip)
    redis.srem("blacklist", ip)
end

function M.check(ip)
    return redis.sismember("blacklist", string.match(ip, "([^:]+)"))
end

function M.list()
    return redis.smembers("blacklist")
end

function M.import(filepath)
    local file = io.open(filepath, "r")
    while true do
        local ip = file:read()
        if not ip then
            break
        end
        M.add(ip)
    end
    file:close()
end

function M.export(filepath)
    local list = M.list()
    local file = io.open(filepath, "w+")
    for _, ip in ipairs(list) do
        file:write(ip.."\n")
    end
    file:close()
end

function M.clear()
    return redis.del "blacklist"
end

return M
