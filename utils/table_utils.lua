
local str_utils = require 'utils.string_utils'

local _M = { _VERSION = '0.1' }

function _M:size(t)
	local count = 0
	for k, v in pairs(t) do
		count = count + 1
	end
	return count
end

function _M:keys(t)
	local keys = {}
	if t == nil then
		return keys;
	end
	for k, v in pairs(t) do
		keys[#keys + 1] = k
	end
	return keys
end

function _M:values(t)
	local values = {}
	if t == nil then
		return values;
	end
	for k, v in pairs(t) do
		values[#values + 1] = v
	end
	return values
end

function _M:contain_key(t, key)
	for k, v in pairs(t) do
		if key == k then
			return true;
		end
	end
	return false;
end

function _M:sort(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	
	table.sort(keys)
	
	local new_t =  {}
	for i, k in pairs(keys) do
		if k and k ~= 'nil' then
			local v = t[k]
			if v then
				if type(v) == 'string' then
					table.insert(new_t, k..'='..v)
				else
					table.insert(new_t, k)
				end
			end
		end
	end
	return new_t
end

function _M:contain_value(t, value)
	for k, v in pairs(t) do
		if value == v then
			return true;
		end
	end
	return false;
end

function _M:merge(dest, src)
	for k, v in pairs(src) do
		dest[k] = v
	end
end

function _M:join(dest, src)
	for _, l in ipairs(src) do
		table.insert(dest, l)
	end
end

function _M:contain_element(t, key)
	for _, k in pairs(t) do
		if key == k then
			return true;
		end
	end
	return false;
end

function _M:filter(t, keys)
	local new_t = {}
	if t == nil then
		return keys;
	end
	for k, v in pairs(t) do
		local eq = false
		for i = 1, #keys do
			local key = keys[i]
			if k == key then
				eq = true
				break
			end
		end
		if not eq then
			new_t[k] = v
		end
	end
	return new_t
end

function _M:filter_startswith(t, key)
	local new_t = {}
	if t == nil then
		return keys;
	end
	for k, v in pairs(t) do
		local match = str_utils:startswith(k, key)
		if not match then
			new_t[k] = v
		end
	end
	return new_t
end

function _M:split_list(line, sep)
	local list = {}
	if line then
		for i, item in pairs(str_utils:split(line, sep)) do
			item = str_utils:trim(item)
			table.insert(list, item)
		end
	end
	return list
end

function _M:join_list(t, sep)
	local val = ''
	for _, item in pairs(t) do
		val = item..sep..val
	end

	if val ~='' then
		if str_utils:endswith(val, sep) then
			val = str_utils:substring(val, 1, string.len(val) - 1)
		end
	end
	return val
end


return _M
