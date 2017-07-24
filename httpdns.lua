
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local cjson = require 'cjson'
local global = require 'global'

local cache_srv = require 'service.cache'
local log_srv = require 'service.log'


local ip_utils = require 'utils.ip_utils'
local io_utils = require 'utils.io_utils'

function dns(domain_name, client_addr)

	local domain_str = cache_srv.get(domain_name)

	if domain_str and domain_str ~= 'null' then

		local domain_cfg = nil
		if not pcall(function(str) domain_cfg = cjson.decode(str) end, domain_str) then
			log_srv.log(log_srv.INFO, domain_name, 'Simple Domain '..domain_str)
			return domain_str
		end

		if domain_cfg then

			local default_host = domain_cfg['default']
			
			local domain_rules = route_cfg['condition']
			if domain_rules then
				for _, rule in pairs(domain_rules) do
					
					local ip = rule['ip']
					if ip == client_addr then
						return rule['host']
					else
						if ip_utils:filter_ip(client_addr, ip) then
							return rule['host']
						end
					end

				end
			end
			return default_host
		end
	end

	log_srv.log(log_srv.ERROR, domain_name, 'Domain is NOT found')
	return nil
end

local function response(domain_name, domain_host)

	local body = {'domain' = domain_name, 'host' = host}
	body = 
	
	ngx.status = ngx.HTTP_OK
	if body then
		ngx.say(cjson.encode(body))
	end
	ngx.exit(ngx.HTTP_OK)
end

local function exception(code, domain_name, message)
	local body = nil
	if type(message) == 'table' then
		body = cjson.encode(message)
	elseif type(message) == 'string' then
		body = cjson.encode({status = code, message = message})
	end
	ngx.status = code
	log_srv.log(log_srv.ERROR, domain_name, message)
	if body then
		ngx.say(body)
	end
	ngx.exit(code)
end

local client_addr = ngx.var.remote_addr

local params = ngx.req.get_uri_args()
local domain_name = params['domain']
if domain_name then

	local domain_host = dns(domain_name, client_addr)
	if domain_host then
		response(domain_name, domain_host)
	else
		exception(ngx.HTTP_BAD_REQUEST, domain_name, 'Domain is NOT found')
	end
else
	exception(ngx.HTTP_BAD_REQUEST, domain_name, 'Domain is None')
end





