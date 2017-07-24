
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local cjson = require 'cjson'

local io_utils = require 'utils.io_utils'
local str_utils = require 'utils.string_utils'
local tab_utils = require 'utils.table_utils'

function get_request_id(client_addr, domain_name, req_time)
	local req_counter = incr_request_count(client_addr, domain_name, req_time)
	local request_id = ngx.md5(table.concat({client_addr, domain_name, req_time, req_counter}, '|'))
	return request_id
end

function incr_request_count(client_addr, domain_name, req_time)
	local sys_config = ngx.shared.sys_config
	local req_counter = sys_config:incr('request-counter', 1)
	if not req_counter then
		req_counter = 1
		sys_config:set('request-counter', req_counter)
	end
	return req_counter
end

function load_config(refresh)

	local sys_config = ngx.shared.sys_config

	if refresh then

		local timeout = 3600

		local cfg_file = ngx.var.cfg_file
		if not cfg_file or cfg_file == '' then
			cfg_file = '/usr/local/nginx/conf/dns.conf'
		end

		local lines = io_utils:read(cfg_file)
		if lines then

			local whitelist = ''

			for _, line in pairs(lines) do
				line = str_utils:trim(line)
				if not str_utils:startswith(line, '#') and line ~= '' then
					local values = str_utils:split(line, '=')
					if table.getn(values) == 2 then
						local key, value = str_utils:trim(values[1]), str_utils:trim(values[2])
						if key == 'forward-whitelist' then
							whitelist = value..';'..whitelist
						end
						sys_config:set(key, value, timeout)
					end
				end
			end
			if str_utils:endswith(whitelist, ';') then
				whitelist = str_utils:substring(whitelist, 1, string.len(whitelist) - 1)
			end
			sys_config:set('forward-whitelist', whitelist, timeout)

			load_redis_nexthop()
			load_redis_whitelist()
			
			load_config_ip()

			sys_config:set('load-config', os.date('%Y-%m-%d %H:%M:%S', os.time()), timeout)

			ngx.log(ngx.WARN, string.format('Load %s success', cfg_file))
			return true
		else
			ngx.log(ngx.ERR, string.format('Load %s fail', cfg_file))
		end


	end
	
	return false
end



function get_config(key, default)

	local timeout = 3600
	
	local sys_config = ngx.shared.sys_config
	local value = sys_config:get(key)

	if not value or value == 'null' or value == 'none' then
		load_config(true)
		value = sys_config:get(key)
	end

	if not value then
		sys_config:set(key, default, timeout)
		return default
	end

	return value

end

function get_all_config()

	if not test_load_config() then 
		load_config(true)
	end

	local config = {}
	
	local sys_config = ngx.shared.sys_config
	local keys = sys_config:get_keys()
	for _, k in pairs(keys) do
		config[k] = sys_config:get(k)
	end

	return config
end



return {

	get_request_id = get_request_id,

	incr_request_count = incr_request_count,

	load_config = load_config,
	get_config = get_config,
	get_all_config = get_all_config

}



