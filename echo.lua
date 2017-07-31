
local cjson = require 'cjson'

ngx.req.read_body()
local body = ngx.req.get_body_data()

local response = {
	client = ngx.var.remote_addr,
	server = {
		name = ngx.var.server_name,
		port = ngx.var.server_port, 
		protocol = ngx.var.server_protocol
	},
	request = {
		scheme = ngx.var.scheme, 
		uri = ngx.var.request_uri,
		method = ngx.req.get_method()
	},
	parameter = ngx.req.get_uri_args(), 
	header = ngx.req.get_headers(),
	body = body
}

ngx.req.set_header('Content-Type', 'application/json')
ngx.req.set_header('Connection', 'close')
ngx.status = ngx.HTTP_OK
if response then
	ngx.say(cjson.encode(response))
end
ngx.exit(ngx.HTTP_OK)



