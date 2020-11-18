etcd-lua
========


etcd http client for lua
this modlue only tested with etcd API V3 under lua5.3 env

Dependencies
===========

- luasocket : https://github.com/diegonehab/luasocket
- luajson : https://github.com/harningt/luajson


Install
=======

copy etcd.lua and base64.lua to lua install path( such as /usr/local/lib/lua/5.3/)

Examples
============
  ```
json = require('cjson')
sr   = require('systeminfo')

etcd = require('etcd').new({
         hosts = {
             "http://ip1:port1",
             "http://ip2:port2",
             "http://ip3:port3"
         },
         prefix = "/v3alpha"
    })


local leaseInfo  = {}
local system     = {}
local net        = "eth0"
local bandwidth  = 100*1024*1024
local interface  = "eth0"
local usage      = {} -- 当前服务器资源占用配置
local started    = false
local cpu_core   = 0
local key        = "/test/127.0.0.1"

function report_system_info()
    local cpu_usage = sr.getCpuOccupy()
    local mem_usage = sr.calcMemUsage()
    local rx_usage, tx_usage = sr.getTxrxUsage(interface)

    if not started then
        system["cpu"] = 0
        system["mem"] = 0
        system["rx"]  = 0
        system["tx"]  = 0

        started = true
    else
        system["cpu"] = sr.calcCpuUsage(usage["cpu"], cpu_usage)
        system["mem"] = mem_usage
        system["rx"], system["tx"]  = sr.calcTxrxUsage(usage["rx"], usage["tx"], rx_usage, tx_usage, bandwidth)
    end

    -- 将当前获取的所有系统信息保存起来，以便计算资源占有率
    usage["cpu"] = cpu_usage
    usage["mem"] = mem_usage
    usage["rx"]  = rx_usage
    usage["tx"]  = tx_usage

    system["country_code"] = "CN"
    system["updated"]      = os.time()

    if etcd ~= nil then
        local res, status = etcd:set(key, system, {timeout = 1, lease=leaseInfo.ID})
        print("res : "..dumpTable(res).."  status : ")
        etcd:keepalive(leaseInfo.ID)
    end

    print("collect system info" .. dumpTable(system))

    local res, status = etcd:get(key, {timeout = 1, lease=leaseInfo.ID})

    print("get key response : "..dumpTable(res).."  status : "..status)
end

-- Methods
function init()
    print("Initializing...")

    if etcd == nil then
        print("Initializ failed since etcd is nil")
        return nil
    end
    print("Initialized")

    -- 申请key的租约, 一秒钟， 租约ID由服务器分配
    local res, status = etcd:grant(1)
    if res == nil then
        print("err is : " .. err)
    end
    print("grant etcd lease response : " .. dumpTable(res))
    if status ~= 200 or res.ID == nil then
        print("grant etcd key lease failed.")
        return nil;
    end

    leaseInfo = {
        ID  = res.ID,
        ttl = 1,
    }

    cpu_core = sr.getCpuCore()

    report_system_info()
end


-- Helper for logging tables
-- https://stackoverflow.com/a/27028488
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

return init()

  ```




