local system = {}

local function getReciseDecimal(nNum, n)
    if type(nNum) ~= "number" then
        return nNum;
    end
    n = n or 0;
    n = math.floor(n)
    if n < 0 then
        n = 0;
    end
    local nDecimal = 10 ^ n
    local nTemp = math.floor(nNum * nDecimal);
    local nRet = nTemp / nDecimal;
    return nRet;
end

function system.getCpuOccupy()

    local fs = io.open("/proc/stat", "r")
    local content = fs:read("l")
    local stat = {}
    --v1, v2 = str:match("val (%d+) | (%d+)")

    print(content)
    local numbers = {}
    local loop = 0
    for num in string.gmatch(content, "%d+") do
        --table.insert(numbers, num)
	numbers[loop] = num
	--print("num :"..numbers[loop])
	loop = loop + 1
	if loop >= 4 then
	    break
	end
    end
    stat["user"] = numbers[0]
    stat["nice"] = numbers[1]
    stat["system"] = numbers[2]
    stat["idle"] = numbers[3]
    fs:close()
    return stat
end

function system.getCpuCore()
    local fs = io.open("/proc/cpuinfo", "r")
    local data = fs:read("*all")
    fs:close()
    local num = 0
    for processor in string.gmatch(data, "(%w+)processor") do
        num = num + 1
    end

    return num
end

function system.calcCpuUsage(last, current)

    local od = last["user"] + last["nice"] + last["system"] + last["idle"]
    local nd = current["user"] + current["nice"] + current["system"] + current["idle"]

    local user = math.abs(current["user"] - last["user"])
    local sys = math.abs(current["system"] - last["system"])

    --print("od :"..od.." nd:"..nd.." user:"..user.."system"..sys)

    if (sys - user) ~= 0 then
        local usage = getReciseDecimal((user + sys + 0.0)/(nd - od), 4)
	return usage
    end

    return 0
end

-- 参考 : https://cloud.tencent.com/developer/article/1663601
function system.calcMemUsage()
    local fm = io.open("/proc/meminfo", "r")
    if not fm then
        return nil, "open /proc/meminfo file failed"
    end

    local content = fm:read("*all")
    fm:close()
    local total = string.match(content, "MemTotal:%s+(%d+)")
    local available = string.match(content, "MemAvailable:%s+(%d+)")
    local usage = (total - available + 0.0) / total

    --print("content is :"..content)
    --print("total: "..total.." available: "..available.." usage: "..usage)
    return getReciseDecimal(usage, 4)
end

-- 参考：https://www.jianshu.com/p/b9e942f3682c
function system.getTxrxUsage(interface)
    local frxtx = io.open("/proc/net/dev", "r")
    if not frxtx then
        return nil,"open /proc/net/dev failed"
    end

    local content = frxtx:read("*all")
    local rxtx = string.match(content, interface..":(.+)")
    --print("rxtx str :"..rxtx)
    if not rxtx then
        return nil,nil, "cannot find target interface"
    end
    --print("rxtx str :"..rxtx)
    local numbers = {}
    local loop = 0
    for num in string.gmatch(rxtx, "(%d+)") do
        numbers[loop] = num
	loop = loop + 1
    end

    --print("rxtx:"..dumpTable(numbers))
    rx = numbers[0]
    tx = numbers[8]

    return rx,tx
end

function system.calcTxrxUsage(rx1, tx1, rx2, tx2, bandwidth)
    local rx_gap = rx2 - rx1 + 0.0
    local tx_gap = tx2 - tx1 + 0.0
    local rx_usage = getReciseDecimal(rx_gap / bandwidth, 4)
    local tx_usage = getReciseDecimal(tx_gap / bandwidth, 4)

    return rx_usage, tx_usage
end

-- Helper for logging tables
-- https://stackoverflow.com/a/27028488
local function dumpTable(o)
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

--[[

local stat1 = getCpuOccupy() 
print("cpu info :"..dumpTable(stat1))

local mem_usage = calcMemUsage()
print("mem usage : "..mem_usage)

local rx, tx = getTxrxUsage("eth0")
print("rx :"..rx.." tx:"..tx)

--]]

return system

