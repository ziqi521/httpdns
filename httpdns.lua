
local cjson = require 'cjson'
local global = require 'global'

local cache_srv = require 'service.cache'
local log_srv = require 'service.log'

local num_utils = require 'utils.number_utils'
local ip_utils = require 'utils.ip_utils'
local io_utils = require 'utils.io_utils'

function dns(client_addr, domain_name)

	local domain_str = cache_srv.get(domain_name)

	if domain_str and domain_str ~= 'null' then

		stat_dns_access(client_addr, domain_name)

		local domain_cfg = nil
		if not pcall(function(str) domain_cfg = cjson.decode(str) end, domain_str) then
			log_srv.log(log_srv.INFO, domain_name, 'Simple Domain '..domain_str)
			return domain_str
		end

		if domain_cfg then

			local default_host = domain_cfg['default']
			
			local domain_rules = domain_cfg['condition']
			if domain_rules then
				for _, rule in pairs(domain_rules) do
					
					local ip = rule['ip']
					if ip == client_addr then
						return select_host(client_addr, domain_name, rule['host'], rule['lbp'])
					else
						if ip_utils:filter_ip(client_addr, ip) then
							return select_host(client_addr, domain_name, rule['host'], rule['lbp'])
						end
					end

				end
			end
			return select_host(client_addr, domain_name, default_host, domain_cfg['lbp'])
		end
	end

	log_srv.log(log_srv.ERROR, domain_name, 'Domain is NOT found')
	return nil
end

function select_host(client_addr, domain_name, domain_host, lbp)
	if type(domain_host) == 'string' then
		return domain_host
	elseif type(domain_host) == 'table' then
		local host_size = #domain_host
		if host_size == 0 then
			return nil
		end

		local host_idx = 0
		
		if lbp == 'polling' then
			local stat_cache = ngx.shared.stat_cache
			local seed = stat_cache:get(string.format('%s:%s:cnt', client_addr, domain_name))
			host_idx = seed % host_size
		else
			local seed = string.sub(ngx.md5(client_addr), -5)
			host_idx = tonumber(num_utils:hex2dec(seed)) % host_size
		end
		return domain_host[host_idx + 1]
	end
end

function stat_dns_access(client_addr, domain_name)
	local stat_cache = ngx.shared.stat_cache
	local dns_flag = string.format('%s:%s:cnt', client_addr, domain_name)
	local req_counter = stat_cache:incr(dns_flag, 1)
	if not req_counter then
		req_counter = 1
		stat_cache:set(dns_flag, req_counter)
	end
	return req_counter
end

function response(domain_name, domain_host)

	local body = {domain = domain_name, host = domain_host}
	
	ngx.status = ngx.HTTP_OK
	if body then
		ngx.say(cjson.encode(body))
	end
	ngx.exit(ngx.HTTP_OK)
end

function exception(code, domain_name, message)
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

function get_client_addr()
	local client_addr = ngx.req.get_headers()['X-Real-IP']
	if not client_addr then
		client_addr = ngx.var.remote_addr
	end
	return client_addr
end

local client_addr = get_client_addr()

local params = ngx.req.get_uri_args()
local domain_name = params['domain']
if domain_name then

	local domain_host = dns(client_addr, domain_name)
	if domain_host then
		response(domain_name, domain_host)
	else
		exception(ngx.HTTP_BAD_REQUEST, domain_name, 'Domain is NOT found')
	end
else
	exception(ngx.HTTP_BAD_REQUEST, domain_name, 'Domain is None')
end





