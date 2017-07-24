
--[[

	Huawei API-Gateway

	Author: Huiyugeng (huiyugeng@huawei.com)
	Date: 2016-07-20

]]

local _M = { _VERSION = '0.1' }

function _M:exists(filename)
	local file = io.open(filename, "r")
	if file then
		io.close(file)
		return true
	end
	return false
end

function _M:read(filename)
	local file = io.open(filename, "r")

	if file then
		local content = {}
		for line in file:lines() do
			table.insert(content, line)
		end
		io.close(file)
		return content
	end
	return nil
end

function _M:write(filename, content, mode)
	mode = mode or "w+b"
	local file = io.open(filename, mode)
	if file then
		if type(content) == 'table' then
			content = table.concat(content, '\n')
		end
		if not file:write(content) then return false end
		io.close(file)
		return true
	else
		return false
	end
end

function _M:append(filename, content)
	return self:write(filename, content, 'a+')
end

function _M:path(path)
	local pos = string.len(path)
	local extpos = pos + 1
	while pos > 0 do
		local b = string.byte(path, pos)
		if b == 46 then -- 46 = char "."
			extpos = pos
		elseif b == 47 then -- 47 = char "/"
			break
		end
		pos = pos - 1
	end

	local dirname = string.sub(path, 1, pos)
	local filename = string.sub(path, pos + 1)
	extpos = extpos - pos
	local basename = string.sub(filename, 1, extpos - 1)
	local extname = string.sub(filename, extpos)
	return {
		dirname = dirname,
		filename = filename,
		basename = basename,
		extname = extname
	}
end

function _M:size(filename)
	local size = false
	local file = io.open(filename, "r")
	if file then
		local current = file:seek()
		size = file:seek("end")
		file:seek("set", current)
		io.close(file)
	end
	return size
end

function _M:execute(cmd)
	local t = io.popen(cmd)
	local ret = t:read('*a')
	return ret
end

return _M
