
local cjson = require 'cjson'
local global = require 'global'

local cache_srv = require 'service.cache'
local log_srv = require 'service.log'

function get_service_uri()

	local req_uri = ngx.var.request_uri

	local s, e = string.find(req_uri, '?')

	if s ~= nil then
		req_sub_uri = string.sub(req_uri, 1, s - 1)
	else
		req_sub_uri = string.sub(req_uri, 1)
	end

	return req_sub_uri
end

function response(request_uri, http_method)
	local resp_content = cache_srv.get(request_uri..':'..http_method)
	
	local status, body = nil, nil
	if resp_content then
		status = ngx.HTTP_OK
		body = resp_content
	else
		status = ngx.HTTP_NOT_FOUND
		body = string.format('Service Mock: %s %s NOT Found', request_uri, http_method)
	end

	log_srv.log(log_srv.INFO, 'mock', string.format('access mock %s:%s status:%d', request_uri, http_method, status))

	ngx.status = status
	ngx.say(body)
	ngx.exit(status)
end

local request_uri = get_service_uri()
local http_method = ngx.req.get_method()

response(request_uri, http_method)
