
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local str_utils = require 'utils.string_utils'
local tab_utils = require 'utils.table_utils'
local num_utils = require 'utils.number_utils'

local _M = { _VERSION = '0.1' }

--[[ 
	IP地址范围度量
	 例如: 255.255.255.255 测量值为0, 255.255.255.0 测量值为 8
	 255.255.0.0 测量值为16, 255.0.0.0 测量值为24, 0.0.0.0 测量值为32 
 ]]
local function _measure_ip(mask)
	local bin_ip = _M:ip2bin(mask)

	if string.len(bin_ip) ~= 32 then return 0 end
	
	local measure = 0
	for i = 1, 32 do
		if string.sub(bin_ip, i, i) == '1' then
			measure = measure + 1
		end
	end
	return 32 - measure

end

--[[ 
	将IP地址进行AND运算 
]]
local function _and_ip(ip1, ip2)
	local function num2bool(num)
		if tonumber(num) == 0 then return false else return true end  
	end
	
	local bin = ''
	if string.len(ip1) == 32 and string.len(ip2) == 32 then
		for i = 1, 32 do
			local j = 0
			if (num2bool(string.sub(ip1, i, i)) and num2bool(string.sub(ip2, i, i))) then
				j = 1
			end
			bin = bin..tostring(j)
		end
	end

	return bin
end

--[[ 
	将子网掩码转换为二进制 
	例如: 24 -> 11111111111111111111111100000000
	255.255.255.0 -> 11111111111111111111111100000000
	
	@param mask: 子网掩码
	@return: 二进制子网掩码
]]
function _M:mask2bin(mask)
	local result = ''
	
	if type(mask) == 'string' then
		result = _M:ip2bin(mask)
	elseif type(mask) == 'number' then
		for i = 1, mask do
			result = result..'1'
		end
	
		for j = 1, 32 - mask do
			result = result..'0'
		end
	else
		result = nil
	end

	return result
end

--[[
	IP地址转换为二进制
	192.168.11.123->11000000101010000000101101111011
	
	@param ip: IP地址
	
	@return: 二进制IP地址
]]
function _M:ip2bin(ip)
	local result = ''
	local ips = str_utils:split(ip, '.')

	for _, _ip in pairs(ips) do
		local bin_ip = num_utils:dec2bin(_ip)
		local len = string.len(bin_ip)

		for i = 1, 8 - len do
			bin_ip = '0'..bin_ip
		end
		result = result..bin_ip

	end

	return result
end

--[[
	IP地址转换为二进制
	11000000101010000000101101111011->192.168.11.123
	
	@param ip: 二进制IP地址
	
	@return: IP地址
]]
function _M:bin2ip(ip)
	local result = {}
	local len = string.len(ip)

	if len == 32 then
		for i = 0, 3 do
			local _ip = num_utils:bin2dec(string.sub(ip, i * 8 + 1, (i + 1) * 8))
			table.insert(result, _ip)
		end
	end

	return table.concat(result, '.')
end

--[[
	判断两个IP是否同一个子网
	
	@param ip1: IP1地址
	@param mask1: IP1地址的子网掩码
	@param ip2: IP2地址
	@param mask2: IP2地址的子网掩码
	
	@return: true 同一子网, false 不同子网 
]]
function _M:is_same_net(ip1, mask1, ip2, mask2)
	local ip1_bin, mask1_bin = self:ip2bin(ip1), self:ip2bin(mask1)

	local ip2_bin, mask2_bin = self:ip2bin(ip2), self:ip2bin(mask2)

	local and1_bin = _and_ip(ip1_bin, mask1_bin)
	local and2_bin = _and_ip(ip2_bin, mask2_bin)

	if and1_bin == and2_bin then
		return true
	else
		return false
	end
end

--[[
	比对两个IP的交叉情况
	
	@param ip1: IP1地址
	@param mask1: IP1地址的子网掩码
	@param ip2: IP2地址
	@param mask2: IP2地址的子网掩码
	
	@return: -1:两个IP不相等, 0：两个IP相等, 1：IP1范围>IP2范围, 2:IP2范围>IP1范围
]]
function _M:compare_ip(ip1, mask1, ip2, mask2)

	local mask1 = _measure_ip(mask1)
	local mask2 = _measure_ip(mask2)

	local ip1_bin = self:ip2bin(ip1)
	local ip2_bin = self:ip2bin(ip2)

	local mask_measure = 0
	if mask1 > mask2 then
		mask_measure = mask1
	else
		mask_measure = mask2
	end

	local ip1_net_bin = string.sub(ip1_bin, 1, 32 - mask_measure)
	local ip2_net_bin = string.sub(ip2_bin, 1, 32 - mask_measure)
	
	if mask1 == mask2 then
		if ip1_net_bin == ip2_net_bin then return 0 end
	else
		if ip1_net_bin == ip2_net_bin then
			local and_bin = _and_ip(ip1_bin, ip2_bin)

			if ip1_bin == and_bin then
				return 1
			elseif ip2_bin == and_bin then
				return 2
			end
		end
	end
	
	return -1
	
end

--[[
	IP地址过滤, 判断SRC_IP是否在IP_LIST中
	
	@param src_ip: 需要过滤的IP地址, 独立的IP地址, 格式: 192.168.100.102
	@param ip_list: IP地址列表, 格式: IP/MASK, 例如: 192.168.100.0/255.255.255.0
	@return: true SRC_IP存在于IP_LIST中, false SRC_IP不存在IP_LIST中
]]
function _M:filter_ip(src_ip, ip_list)
	local ips = ip_list 
	if type(ip_list) == 'string' then
		ips = str_utils:split(ip_list, ',')
	end
	for _, _ip in pairs(ips) do
		if _ip ~= nil then
			_ip = str_utils:trim(_ip)
			if src_ip == _ip then
				return true
			end
			local ip = str_utils:split(_ip, '/')
			if tab_utils:size(ip) == 2 then
				local result = self:compare_ip(src_ip, '255.255.255.255', ip[1], ip[2])
				if result == 0 or result == 2 then
					return true
				end
			end
		end
	end
	return false
end

return _M
