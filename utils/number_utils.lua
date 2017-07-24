
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local _M = { _VERSION = '0.1' }

function _M:bin2dec(str_num)
	
	local result = 0
	local len = string.len(str_num)
	
	local i = len
	while i > 0  do
		local j = string.sub(str_num, i, i)
		result = result + (tonumber(j) * 2 ^ (len - i))
		i = i - 1
	end
	return tostring(result)
end

function _M:dec2bin(str_num)
	local num = tonumber(str_num)
	local floor = math.floor

	local result = ''
	while true do
		if num == 0 then break end
		result = tostring(num % 2)..result
		num = floor(num / 2)
	end

	return result
end

function _M:hex2dec(str_num)

	local result = 0
	local len = string.len(str_num)
	
	local i = len
	while i > 0  do
		local j = string.upper(string.sub(str_num, i, i))
		
		local num = -1
		if j == 'A' then num = 10 end
		if j == 'B' then num = 11 end
		if j == 'C' then num = 12 end
		if j == 'D' then num = 13 end
		if j == 'E' then num = 14 end
		if j == 'F' then num = 15 end
		if num == -1 then
			num = tonumber(j)
		end
		local t = num * 16 ^ (len - i)
		result = t + result
		i = i - 1
	end
	
	return tostring(result)
end

function _M:dec2hex(str_num)
	local num = tonumber(math.abs(str_num))
	
	local result = ''
	while num > 0 do
		local decimal = num % 16
		num = math.floor(num / 16)
		result = string.format('%X', tostring(decimal))..result
	end
	return result
end


function _M:hex2bin(str_num)
	local dec = _M:hex2dec(str_num)
	return _M:dec2bin(dec)
end


function _M:bin2hex(str_num)
	local dec = _M:bin2dec(str_num)
	return _M:dec2hex(dec)
end

return _M
