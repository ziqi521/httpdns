
local cjson = require 'cjson'
local global = require 'global'

local function redis_facrory(h)
    
	local h = h

	h.redis = require('resty.redis')
	h.cosocket_pool = {max_idel = 10000, size = 200}

	h.commands = {
        "append",            "auth",              "bgrewriteaof",
        "bgsave",            "bitcount",          "bitop",
        "blpop",             "brpop",
        "brpoplpush",        "client",            "config",
        "dbsize",
        "debug",             "decr",              "decrby",
        "del",               "discard",           "dump",
        "echo",
        "eval",              "exec",              "exists",
        "expire",            "expireat",          "flushall",
        "flushdb",           "get",               "getbit",
        "getrange",          "getset",            "hdel",
        "hexists",           "hget",              "hgetall",
        "hincrby",           "hincrbyfloat",      "hkeys",
        "hlen",
        "hmget",             "hmset",             "hscan",
        "hset",
        "hsetnx",            "hvals",             "incr",
        "incrby",            "incrbyfloat",       "info",
        "keys",
        "lastsave",          "lindex",            "linsert",
        "llen",              "lpop",              "lpush",
        "lpushx",            "lrange",            "lrem",
        "lset",              "ltrim",             "mget",
        "migrate",
        "monitor",           "move",              "mset",
        "msetnx",            "multi",             "object",
        "persist",           "pexpire",           "pexpireat",
        "ping",              "psetex",            "psubscribe",
        "pttl",
        "publish",           "punsubscribe",      "pubsub",
        "quit",
        "randomkey",         "rename",            "renamenx",
        "restore",
        "rpop",              "rpoplpush",         "rpush",
        "rpushx",            "sadd",              "save",
        "scan",              "scard",             "script",
        "sdiff",             "sdiffstore",
        "select",            "set",               "setbit",
        "setex",             "setnx",             "setrange",
        "shutdown",          "sinter",            "sinterstore",
        "sismember",         "slaveof",           "slowlog",
        "smembers",          "smove",             "sort",
        "spop",              "srandmember",       "srem",
        "sscan",
        "strlen",            "subscribe",         "sunion",
        "sunionstore",       "sync",              "time",
        "ttl",
        "type",              "unsubscribe",       "unwatch",
        "watch",             "zadd",              "zcard",
        "zcount",            "zincrby",           "zinterstore",
        "zrange",            "zrangebyscore",     "zrank",
        "zrem",              "zremrangebyrank",   "zremrangebyscore",
        "zrevrange",         "zrevrangebyscore",  "zrevrank",
        "zscan",
        "zscore",            "zunionstore",       "evalsha",
        -- resty redis private command
        "set_keepalive",     "init_pipeline",     "commit_pipeline",      
        "array_to_hash",     "add_commands",      "get_reused_times",
    }

	h.connect = function()

		if not h.host then
			h.host = global.get_config('redis-host', '127.0.0.1')
		end
		if not h.port then
			h.port = tonumber(global.get_config('redis-port', '6379'))
		end
		if not h.pass then
			h.pass = global.get_config('redis-pass', '')
		end
		if not h.database then
			h.database = tonumber(global.get_config('redis-db', '0'))
		end

		local instance = h.redis:new()
		instance:set_timeout(10000)
		if not instance:connect(h.host, h.port) then 
			return false, nil
		end
		if h.pass ~= '' then
			instance:auth(h.pass)
		end
		instance:select(h.database)
		return true, instance
	end

	h.spawn_client = function(h, name)

		local self = {}
		self.name = name
		self.instance = nil
		self.connect = nil

		-- construct
		self.construct = function(_, h, name)
			-- set info
			self.name = name
			self.connect = h.connect

			-- gen redis proxy client
			for _, v in pairs(h.commands) do
				self[v] = function(self, ...)
					-- instance test and reconnect  
					if (type(self.instance) == 'userdata: NULL' or type(self.instance) == 'nil') then
						local ok
						ok, self.instance = self.connect()
						if not ok then return false end
					end
					-- get data
					return self.instance[v](self.instance, ...)
				end
			end
			return true
		end

		-- do construct
		self:construct(h, name) 

		return self
	end

	local self = {}

	self.pool = {} -- redis client name pool

	self.construct = function()
		return
	end

	self.spawn = function( _, name)
		if self.pool[name] == nil then
			ngx.ctx[name] = h.spawn_client(h, name) 
			self.pool[name] = true
			return true, ngx.ctx[name]
		else
			local client = ngx.ctx[name]
			if not client then
				client = h.spawn_client(h, name)
			end
			return true, client
		end
	end

	self.destruct = function()
		local allok = true
		for name, _ in pairs(self.pool) do
			local ok, msg = ngx.ctx[name].instance:set_keepalive(
				h.cosocket_pool.max_idel, h.cosocket_pool.size
			)
			if not ok then allok = false end 
		end
		return allok
	end

	self.construct() 

	return self
end

local function get_config()
	local sys_config = ngx.shared.sys_config
	local value = sys_config:get(key)

	if not value then
		sys_config:set(key, default, timeout)
		return default
	end

	return value
end

local redis_config = {}

do
	redis = redis_facrory(redis_config)
end

local function has_redis_key(key)
	local ok, rclient = redis:spawn('redis')

	if ok and key then
		local result = ''

		result = rclient:get(key)
		local rst_type = type(result)
		if rst_type == 'userdata' then
			result = cjson.encode(result)
		end
		if result ~= nil and result ~= 'null' then
			return true
		end
	end
	return false
end

local function get_redis_value(key, sub_key)

	local ok, rclient = redis:spawn('redis')

	if ok and key then
		local result = ''
		if sub_key then
			result = rclient:hmget(key, sub_key)
		else
			result = rclient:get(key)
		end

		if result ~= nil then
			local rst_type = type(result)
			if rst_type == 'userdata' then
				return cjson.encode(result)
			else
				return result
			end
		end
	end
	return nil
end

local function set_redis_value(key, value)
	local ok, rclient = redis:spawn('redis')

	if ok and value then
		if type(value) == 'table' then
			rclient:hmset(key, value)
		else
			rclient:set(key, value)
		end
	end

	if get_redis_value(key) then
		return true
	else
		return false
	end
end

local function list_redis_keys(pattern)
	local ok, rclient = redis:spawn('redis')
	if ok and pattern then
		result = rclient:keys(pattern)
		return result
	end
	return nil
end

local function del_redis_key(keys)
	local ok, rclient = redis:spawn('redis')
	if ok then
		if type(keys) == 'table' then
			for i = 1, #keys do
				local key = keys[i]
				rclient:del(key)
			end
		else
			rclient:del(keys)
		end
		return true
	end
	return false
end

return {
	has_key = has_redis_key,
	set = set_redis_value,
	get = get_redis_value,
	del = del_redis_key,
	keys = list_redis_keys,
}
