local http = require("socket.http")
local ltn12 = require("ltn12")

local function splitStr(str, delimeter)
    local find, sub, insert = string.find, string.sub, table.insert
    local res = {}
    local start, start_pos, end_pos = 1, 1, 1
    while true do
        start_pos, end_pos = find(str, delimeter, start, true)
        if not start_pos then
            break
        end
        insert(res, sub(str, start, start_pos - 1))
        start = end_pos + 1
    end
    insert(res, sub(str,start))
    return res
end

string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

function dumpTable(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dumpTable(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

local fus = io.popen("top -n 1 |grep Cpu | cut -d \",\" -f 1 | cut -d \":\" -f 2")
local usstr = fus:read("*all")
print("us .." .. usstr)
local sstr = string.split(usstr, " ")
print(dumpTable(sstr))
local us = sstr[2] + 0
print("us val = " .. us)

local str = string.split("0.7 us", " us")

print("str = " .. dumpTable(str))

for _, s in ipairs(str)  do
    print(s)
end

print("str" .. str[1])


-- The Request Bin test URL: http://requestb.in/12j0kaq1
function sendRequest()
    local path = "http://129.204.249.76:30104/v3alpha/kv/put"
    local payload = [[ {"key":"aaa","value":"123456"} ]]
    local response_body = { }

    local res, code, response_headers, status = http.request
    {
        url = path,
        method = "POST",
        headers =
        {
            ["Authorization"] = "Maybe you need an Authorization header?",
            ["Content-Type"] = "application/json",
            ["Content-Length"] = payload:len()
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body)
    }

    print("qqqq")

    if type(response_body) == "table" then
        for k, v in pairs(response_body) do
            print(k, v)
        end
    end

end

sendRequest()

