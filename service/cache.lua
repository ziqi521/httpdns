
local global = require 'global'

local redis_srv = require 'service.redis'

local function set(key, value, exptime)
	if not key or not value then
		return false, 'key or value is nil'
	end
	local usr_cache = ngx.shared.usr_cache
	local val_type = type(value)
	if val_type ~= 'number' and val_type ~= 'string' and val_type ~= 'boolean' then
		return false, string.format('unsupport %s (%s) to add into cache', key, val_type)
	end

	if not exptime or type(exptime) ~= 'number' then
		exptime = tonumber(global.get_config('cache-timeout', '60'))
	end

	usr_cache:set(key, value, exptime)
	local tmp_val = usr_cache:get(key)
	if tmp_val and tmp_val ~= 'none' then
		return true, nil
	else
		return false, 'set value fail'
	end
end

local function get(key)
	local usr_cache = ngx.shared.usr_cache
	local value = usr_cache:get(key)
	if not value or value =='null' then
		value = redis_srv.get(key)
		if value then
			local exptime = tonumber(global.get_config('cache-timeout', '60'))
			usr_cache:set(key, value, exptime)
		end
	end
	return value
end

local function refresh(key)
	local usr_cache = ngx.shared.usr_cache
	local value = redis_srv.get(key)
	local exptime = tonumber(global.get_config('cache-timeout', '60'))
	if value then
		usr_cache:set(key, value, exptime)
		return true
	end
	return false
end

local function flush()
	local usr_cache = ngx.shared.usr_cache
	usr_cache:flush_all()
end

return {
	set = set,
	get = get,
	refresh = refresh,
	flush = flush
}
