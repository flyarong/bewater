--  微信验证(access_token和ticket需要在服务中缓存!)
--
local skynet    = require "skynet"
local json      = require "cjson.safe"
local bewater   = require "bw.bewater"
local sha256    = require "bw.auth.sha256"
local http      = require "bw.http"

local function url_encoding(tbl, encode)
    local data = {}
    for k, v in pairs(tbl) do
        table.insert(data, string.format("%s=%s", k, v))
    end

    local url = table.concat(data, "&")
    if encode then
        return string.gsub(url, "([^A-Za-z0-9])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    else
        return url
    end
end

local M = {}

function M.request_access_token(appid, secret)
    assert(appid and secret)
    local ret, resp = http.get("https://api.weixin.qq.com/cgi-bin/token", {
        grant_type  = "client_credential",
        appid       = appid,
        secret      = secret,
    })
    resp = json.decode(resp)
    if resp then
        return resp.access_token, resp.expires_in
    else
        error(string.format("request_access_token error, appid:%s, secret:%s", appid, secret))
    end
end

function M.request_ticket(appid, token)
    assert(appid)
    local ret, resp = http.get("https://api.weixin.qq.com/cgi-bin/ticket/getticket", {
        access_token = token,
        type = 2,
    })
    resp = json.decode(resp)
    if resp then
        return resp.ticket, resp.expires_in
    else
        error(string.format("request_ticket error, appid:%s, token:%s", appid, token))
    end
end

function M.check_code(appid, secret, js_code)
    assert(appid and secret and js_code)
    local ret, resp = http.get("https://api.weixin.qq.com/sns/jscode2session",{
        js_code = js_code,
        grant_type = "authorization_code",
        appid = appid,
        secret = secret,
    })
    if resp then
        return json.decode(resp)
    else
        error(string.format("check_code error, appid:%s, secret:%s, js_code:%s",
        appid, secret, js_code))
    end
end

-- data {score = 100, gold = 300}
function M.set_user_storage(appid, access_token, openid, session_key, data)
    local kv_list = {}
    for k, v in pairs(data) do
        table.insert(kv_list, {key = k, value = v})
    end
    local post = json.encode({kv_list = kv_list})
    local url = "https://api.weixin.qq.com/wxa/set_user_storage?"..url_encoding({
        access_token = access_token,
        openid = openid,
        appid = appid,
        signature = sha256.hmac_sha256(post, session_key),
        sig_method = "hmac_sha256",
    })
    local ret, resp = http.post(url, post)
    if resp then
        return json.decode(resp)
    else
        error(string.format("set_user_storage error, appid:%s, access_token:%s, openid:%s, session_key:%s, data:%s",
        appid, access_token, openid, session_key, data))
    end
end

-- key_list {"score", "gold"}
function M.remove_user_storage(appid, access_token, openid, session_key, key_list)
    local post = json.encode({key = key_list})
    local url = "https://api.weixin.qq.com/wxa/remove_user_storage?"..url_encoding({
        access_token = access_token,
        openid = openid,
        appid = appid,
        signature = sha256.hmac_sha256(post, session_key),
        sig_method = "hmac_sha256",
    })
    local ret, resp = http.post(url, post)
    if resp then
        return json.decode(resp)
    else
        error(string.format("remove_user_storage error, appid:%s, access_token:%s, openid:%s, session_key:%s",
        appid, access_token, openid, session_key))
    end
end

return M
