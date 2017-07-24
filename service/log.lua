
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local global = require 'global'

local io_utils = require 'utils.io_utils'

local LOG_LEVEL = {
	ALERT = 1,    -- Alert: action must be taken immediately
	CRITICAL = 2, -- Critical: critical conditions
	ERROR = 3,    -- Error: error conditions
	WARN = 4,     -- Warning: warning conditions
	NOTICE = 5,   -- Notice: normal but significant condition
	INFO = 6,     -- Informational: informational messages
	DEBUG = 7,    -- Debug: debug-level messages
}

function init_logger()

	local log_cfg = global.get_config('log', 'true')
	ngx.ctx['log'] = log_cfg

	if log_cfg and log_cfg == 'true' then

		ngx.ctx['log-level'] =  LOG_LEVEL[global.get_config('log-level', 'NOTICE')]

		local log_file = string.format('%s/dns.log', global.get_config('log-path'))
		ngx.ctx['log-file'] = log_file
	end

	return log_cfg
end

function log(level, domain, msg)

	local logger = ngx.ctx['log']
	if not logger then
		logger = init_logger()
	end

	if logger and logger == 'true' then
		
		local log_level = ngx.ctx['log-level']
		if level > log_level then
			return
		end

		local server_addr = ngx.var.server_name
		local client_addr = ngx.var.remote_addr

		local msg_body = string.format('client=%s, domain=%s, message=%s', client_addr, domain, msg)
		
		local log_msg = string.format('<%s> %s %s [%s:%s]: %s', 
			level, ngx.localtime(), server_addr, 
			ngx.worker.pid(), ngx.worker.id(), msg_body)

		local log_file = ngx.ctx['log-file']
		if log_file then
			io_utils:append(log_file, log_msg..'\n')
		end
	end
end


local _M = {
	init = init_log,
	log = log
}

setmetatable(_M, { __index = LOG_LEVEL} )

return _M