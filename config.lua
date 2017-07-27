
local cjson = require 'cjson'
local global = require 'global'

local cache_srv = require 'service.cache'
local log_srv = require 'service.log'
local redis_srv = require 'service.redis'

function get_config_uri()
	local base_path = '/config'
	local req_uri = ngx.var.request_uri

	local s, e = string.find(req_uri, '?')

	if s ~= nil then
		req_sub_uri = string.sub(req_uri, string.len(base_path) + 1, s - 1)
	else
		req_sub_uri = string.sub(req_uri, string.len(base_path) + 1)
	end

	return req_sub_uri
end

function response(code, domain_name, message)
	local body = cjson.encode({status = code, message = message})
	ngx.status = code
	log_srv.log(log_srv.ERROR, domain_name, message)
	if body then
		ngx.say(body)
	end
	ngx.exit(code)
end

function publish_domain()

	local params = ngx.req.get_uri_args()
	local domain_name = params['domain']

	if domain_name then

		ngx.req.read_body()
		local domain_cfg = ngx.req.get_body_data()

		if domain_cfg then

			local ok_redis = redis_srv.set(domain_name, domain_cfg)
			local ok_cache, msg_cache = cache_srv.set(domain_name, domain_cfg)

			if ok_redis and ok_cache then
				response(ngx.HTTP_OK, domain_name, string.format('%s publish success', domain_name))
			else
				local msg = nil
				if not ok_cache then
					msg = string.format('Set %s fail: %s', domain_name, msg_cache)
				else
					msg = string.format('Set %s fail', domain_name)
				end
				response(ngx.HTTP_INTERNAL_SERVER_ERROR, domain_name, msg)
			end
		else
			response(ngx.HTTP_INTERNAL_SERVER_ERROR, domain_name, 'Domain config is nil')
		end
	else
		response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'config', 'Domain name is nil')
	end

end

function flush_dns()
	cache_srv.flush()
	response(ngx.HTTP_OK, 'config', 'Flush DNS cache successful')
end

function reset_stat()
	local req_args = ngx.req.get_uri_args()
	local client_addr = req_args['ip']
	local domain_name = req_args['domain']

	if client_addr and domain_name then
		local dns_flag = string.format('%s:%s:cnt', client_addr, domain_name)
		local stat_cache = ngx.shared.stat_cache

		if stat_cache:get(dns_flag) ~= nil then
			stat_cache:set(dns_flag, 0)
		end

		response(ngx.HTTP_OK, 'config', string.format('Reset %s Stat successful', dns_flag))
	else
		response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'config', 'One or More Parameter is nil')
	end

end

local service_uri = get_config_uri()
local http_method = ngx.req.get_method()

local service = {
	publish = {publish_domain, 'POST'},
	flush = {flush_dns, 'GET'},
	reset = {reset_stat, 'GET'}
}

local service_name = string.sub(service_uri, 2)
local func = service[service_name]

if func then
	if #func == 2 then
		if http_method == func[2] then
			func[1]()
		else
			response(ngx.HTTP_NOT_ALLOWED, 'config', 'Unsupport HTTP method '..http_method)
		end
	else
		response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'config', 'Bad Service Config '..service_name)
	end
else
	response(ngx.HTTP_NOT_FOUND, 'config', 'Unknown service: '..service_name)
end