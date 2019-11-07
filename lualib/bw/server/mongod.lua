local skynet  = require "skynet.manager"
local mongo   = require "skynet.db.mongo"
local bewater = require "bw.bewater"
local util    = require "bw.util"
local log     = require "bw.log"

local db

local M = {}
function M.find_one(name, query, selector)
    local data = db[name]:findOne(query, selector)
    return util.str2num(data)
end

function M.find_one_with_default(name, query, default, selector)
    local data = db[name]:findOne(query, selector)
    if not data then
        M.insert(name, default)
        return default
    end
    return util.str2num(data)
end

-- todo 此方法返回可能大于消息长度
function M.find(name, query, selector)
    local ret = db[name]:find(query, selector)
    local data = {}
    while ret:hasNext() do
        table.insert(data, ret:next())
    end
    return util.str2num(data)
end

function M.update(name, query_tbl, update_tbl)
    update_tbl = util.num2str(update_tbl)
    local ok, err, r = db[name]:findAndModify({query = query_tbl, update = update_tbl})
    if not ok then
        log.error("mongo update error", r)
        error(err)
    end
    return true
end

function M.insert(name, tbl)
    tbl = util.num2str(tbl)
    local ok, err, r = db[name]:safe_insert(tbl)
    if not ok then
        log.error("mongo update error", r)
        error(err)
    end
    return true
end

function M.delete(name, query_tbl)
    db[name]:delete(query_tbl)
    return true
end

function M.drop(name)
    return db[name]:drop()
end

function M.get(key, default)
    local ret = db.global:findOne({key = key})
    if ret then
        return util.str2num(ret.value)
    else
        db.global:safe_insert({key = key, value = default})
        return default
    end
end

function M.set(key, value)
    value = util.num2str(value)
    db.global:findAndModify({
        query = {key = key},
        update = {key = key, value = value},
    })
end

return function(conf)
    skynet.start(function()
        assert(conf.host and conf.port and conf.name)
        db = mongo.client({
            host = conf.host,
            port = conf.port,
        })[conf.name]
        skynet.dispatch("lua", function(_, _, cmd, ...)
            local f = assert(M[cmd], ...)
            bewater.ret(f(...))
        end)
    end)
end
