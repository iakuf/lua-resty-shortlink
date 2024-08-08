-- shortlink.lua
local _M = {}

local redis = require "resty.redis"
local cjson = require "cjson"
local resty_random = require "resty.random"
local str = require "resty.string"

-- 默认的 Redis 配置
local redis_host = "127.0.0.1"
local redis_port = 6379
local redis_timeout = 1000
local redirect_domain = "http://yourdomain.com"

-- 初始化模块时传入 Redis 配置
function _M.init(config)
    redis_host = config.host or redis_host
    redis_port = config.port or redis_port
    redis_timeout = config.timeout or redis_timeout
    redirect_domain = config.domain or redirect_domain
end

-- 连接 Redis 的函数
local function connect_redis()
    local red = redis:new()
    red:set_timeout(redis_timeout) -- 设置超时时间

    local ok, err = red:connect(redis_host, redis_port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return nil
    end

    return red
end

-- 生成唯一的短链接，8个字符长
local function generate_short_link()
    local bytes = resty_random.bytes(4) -- 生成4字节的随机字符串
    return str.to_hex(bytes)
end

function _M.create()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    local params = cjson.decode(data)

    if not params.url or not params.expiry then
        ngx.status = 400
        ngx.say(cjson.encode({ error = "missing url or expiry" }))
        return
    end

    local red = connect_redis()
    if not red then
        return
    end

     -- 首先检查该 URL 是否已经存在
    local existing_short_link, err = red:get("url:" .. params.url)
    if existing_short_link and existing_short_link ~= ngx.null then
        ngx.say(cjson.encode({ short_link = redirect_domain .. "/" .. existing_short_link }))
        return
    end

    local short_link = generate_short_link()
    local key_exists = red:exists("short:" .. short_link)

     repeat
        -- 使用 SETNX 来确保唯一性
        res, err = red:setnx("short:" .. short_link, params.url)
        if res == 0 then
            short_link = generate_short_link() -- 冲突时重新生成短链接
        elseif not res then
            ngx.say("failed to set short link: ", err)
            return
        end
    until res == 1
    
    -- 将原始 URL 与短链接映射并保存
    red:set("url:" .. params.url, short_link)

    -- 设置链接的过期时间
    red:expire("short:" .. short_link, params.expiry)
    red:expire("url:" .. params.url, params.expiry)

    ngx.say(cjson.encode({ short_link = redirect_domain .. "/" .. short_link }))
end

function _M.redirect()
    local red = connect_redis()
    if not red then
        return
    end

    local short_link = ngx.var.uri:sub(2) -- 获取短链接代码部分
    local url, err = red:get("short:" .. short_link)

    if not url then
        ngx.status = 404
        ngx.say("Link not found: ", err)
        return
    end

    if url == ngx.null then
        ngx.status = 404
        ngx.say("Link expired or not found")
        return
    end

    ngx.redirect(url, 302)
end

return _M

