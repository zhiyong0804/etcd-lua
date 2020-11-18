
--local typeof = require("typeof")
local cjson  = require('cjson.safe')
local http   = require('socket.http')
local ltn12  = require('ltn12')
local base64 = require('base64')
local decode_json   = cjson.decode
local encode_json   = cjson.encode
local encode_base64 = base64.encode
local decode_base64 = base64.decode

local M = {}
local Etcd = {}

local function encode_json_base64(data)
    local err
    data, err = encode_json(data)
    if not data then
        return nil, err
    end
    return encode_base64(data)
end

local function to_query(data)
    local entries = {}
    for k, v in pairs(data) do
        if v ~= nil then
            table.insert(entries, k .. '=' .. tostring(v))
        end
    end
    return table.concat(entries, '&')
end

local function choose_host(self)
    local hosts = self.hosts
    local hosts_size = #hosts
    self.selected_host = self.selected_host + 1;
	if self.selected_host > hosts_size then
 	    self.selected_host = 1
	end

    return hosts[self.selected_host]
end

local function request_uri(method, uri, opts, timeout)
    local http_opts = {
        url=uri,
        headers={}
    }

    if method ~= nil then http_opts.method = method end

    if opts.body ~= nil then
        if http_opts.method == 'GET' or http_opts.method == 'DELETE' then
            http_opts.url = http_opts.url .. '?' .. to_query(opts.body)
        else
            --local data = to_query(opts.body)
	    local body = encode_json(opts.body)
            http_opts.source = ltn12.source.string(body)
            http_opts.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            http_opts.headers['Content-Length'] = #body
        end
    end

    local buffer = {}
    http_opts.sink = ltn12.sink.table(buffer)

    --print("http_opts : " .. dumpTable(http_opts))
    local res, status = http.request(http_opts)
    local response_text = table.concat(buffer)

    --print("status=" .. status .. "response=" .. response_text);

    if res == nil then
        return nil, status
    else
        return cjson.decode(response_text), status
    end
end

local function encode_args(data)
    local entries = {}
    for k, v in pairs(data) do
        if v ~= nil then
            table.insert(entries, k .. '=' .. tostring(v))
        end
    end
    return table.concat(entries, '&')
end

function Etcd:set(key, val, attr)
    -- verify key
    if key == '/' then
        return nil, "key should not be a slash"
    end

    key = encode_base64(key)
    local err
    val, err = encode_json_base64(val)
    if not val then
        return nil, err
    end
    -- print("value is " .. val)

    attr = attr or {}

    local lease
    if attr.lease then
        lease = attr.lease and attr.lease or 0
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    local ignore_value
    if attr.ignore_value then
        ignore_value = attr.ignore_value and true or false
    end

    local ignore_lease
    if attr.ignore_lease then
        ignore_lease = attr.ignore_lease and true or false
    end

    local opts = {
        body = {
            value        = val,
            key          = key,
            lease        = lease,
            prev_kv      = prev_kv,
            ignore_value = ignore_value,
            ignore_lease = ignore_lease,
        }
    }

    --print("self " .. dumpTable(self))

    local res, status = request_uri('POST',
                           self.addr .. self.prefix .. "/kv/put",
                           opts, self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
        return request_uri('POST',
                           self.addr .. self.prefix .. "/kv/put",
                           opts, self.timeout)
    end

    return res, status
end

function Etcd:get(key, attr)
    -- verify key
    if not key or key == '/' then
        return nil, "key invalid"
    end

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local limit
    if attr.limit then
        limit = attr.limit and attr.limit or 0
    end

    local revision
    if attr.revision then
        revision = attr.revision and attr.revision or 0
    end

    local sort_order
    if attr.sort_order then
        sort_order = attr.sort_order and attr.sort_order or 0
    end

    local sort_target
    if attr.sort_target then
        sort_target = attr.sort_target and attr.sort_target or 0
    end

    local serializable
    if attr.serializable then
        serializable = attr.serializable and true or false
    end

    local keys_only
    if attr.keys_only then
        keys_only = attr.keys_only and true or false
    end

    local count_only
    if attr.count_only then
        count_only = attr.count_only and true or false
    end

    local min_mod_revision
    if attr.min_mod_revision then
        min_mod_revision = attr.min_mod_revision or 0
    end

    local max_mod_revision
    if attr.max_mod_revision then
        max_mod_revision = attr.max_mod_revision or 0
    end

    local min_create_revision
    if attr.min_create_revision then
        min_create_revision = attr.min_create_revision or 0
    end

    local max_create_revision
    if attr.max_create_revision then
        max_create_revision = attr.max_create_revision or 0
    end

    key = encode_base64(key)

    local opts = {
        body = {
            key                 = key,
            range_end           = range_end,
            limit               = limit,
            revision            = revision,
            sort_order          = sort_order,
            sort_target         = sort_target,
            serializable        = serializable,
            keys_only           = keys_only,
            count_only          = count_only,
            min_mod_revision    = min_mod_revision,
            max_mod_revision    = max_mod_revision,
            min_create_revision = min_create_revision,
            max_create_revision = max_create_revision
        }
    }

    local res, status = request_uri("POST",
                             self.addr .. self.prefix .. "/kv/range",
                             opts, attr and attr.timeout or self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
        res, status = request_uri("POST",
                             self.addr .. self.prefix .. "/kv/range",
                             opts, attr and attr.timeout or self.timeout)
    end

    if res and status == 200 then
        for _, kv in ipairs(res.kvs) do
            kv.key = decode_base64(kv.key)
            kv.value = decode_base64(kv.value)
            kv.value = cjson.decode(kv.value)
        end
    end

    return res, status
end

-- 申请租约，ttl 租约时间，需要每隔一段时间去刷新， id为租约的ID，如果为0则由服务器分配
function Etcd:grant(ttl, id)
    if ttl == nil then
        return nil, "lease grant command needs TTL argument"
    end

    --if not typeof.int(ttl) then
    if not type(ttl) == 'number' then
        return nil, 'ttl must be integer'
    end

    id = id or 0
    local opts = {
        body = {
            TTL = ttl,
            ID = id
        },
    }

    res, status = request_uri('POST',
                       self.addr .. self.prefix .. "/lease/grant",
                       opts, self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
        return request_uri('POST',
                       self.addr .. self.prefix .. "/lease/grant",
                       opts, self.timeout)
	end

    return res, status
end

-- 获取所有租约信息
function Etcd:leases()

    res, status = request_uri('POST',
                       self.addr .. self.prefix .. "/lease/leases",
                       opts, self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
        request_uri('POST',
                       self.addr .. self.prefix .. "/lease/leases",
                       opts, self.timeout)
    end

    return res, status
end

function Etcd:delete(key, attr)
    attr = attr and attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    key = encode_base64(key)

    local opts = {
        body = {
            key       = key,
            range_end = range_end,
            prev_kv   = prev_kv,
        },
    }

    res, status = request_uri("POST",
                       self.addr .. self.prefix .. "/kv/deleterange",
                       opts, self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
        return request_uri("POST",
                       self.addr .. self.prefix .. "/kv/deleterange",
                       opts, self.timeout)
    end

    return res, status
end

function Etcd:revoke(id)
    if id == nil then
        return nil, "lease revoke command needs ID argument"
    end

    local opts = {
        body = {
            ID = id
        },
    }

    res, status = request_uri("POST",
                       self.addr .. self.prefix .. "/kv/lease/revoke",
                       opts, self.timeout)
    if status ~= nil and status ~= 200 then
        self.addr = choose_host(self)
	return request_uri("POST",
                       self.addr .. self.prefix .. "/kv/lease/revoke",
                       opts, self.timeout)
    end

    return res, status
end

-- 续租租约，id为租约ID
function Etcd:keepalive(id)
    if id == nil then
        return nil, "lease keepalive command needs ID argument"
    end

    local opts = {
        body = {
            ID = id
        },
    }

    res, status = request_uri("POST",
                       self.addr .. self.prefix .. "/lease/keepalive",
                       opts, self.timeout)
    if  status ~= nil and status ~= 200 then
	    self.addr = choose_host(self)
	    return request_uri("POST",
                       self.addr .. self.prefix .. "/lease/keepalive",
                       opts, self.timeout)
    end

    return res, status
end

local function dumpTable(o)
    if o == nil then return "" end
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

function M.new(opts)
    local self = {}

    -- 初始化的时候选择第一个host，以后如果请求返回非200时，轮回选择
    if type(opts.hosts) ~= 'table' and  type(opts.hosts) ~= "string" then
        return nil, "hosts must be string or string table"
    end
    if type(opts.hosts) == "string" then
        self.hosts = {opts.hosts}
        self.addr  = opts.hosts or 'http://127.0.0.1:2379'
    else
	self.selected_host = 1
	self.is_cluster    = true
	self.hosts         = opts.hosts
	self.addr          = opts.hosts[1] or 'http://127.0.0.1:2379'
    end

    self.prefix = opts.prefix

    --print(dumpTable(self))

    setmetatable(self, {__index = Etcd})
    return self
end

return M

