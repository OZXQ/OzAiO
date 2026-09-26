-- ============================================================
-- WoW 1.12 基础函数库（精简版）
-- 保留：数学扩展 / 字符串处理 / 打印系统 / 常用工具
-- ============================================================

-- ---------- 局部化常用全局 ----------
local error = error
local next = next
local pairs = pairs
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack
local abs, ceil, exp, floor = math.abs, math.ceil, math.exp, math.floor
local find, format, gfind, gsub, len, sub = string.find, string.format, string.gfind, string.gsub, string.len, string.sub
local concat = table.concat

local MAXN = 2147483647

-- ============================================================
-- 1. select 补全（1.12 原版有缺陷）
-- ============================================================
function select(n, ...)
    if not (type(n) == "number" or (type(n) == "string" and n == "#")) then
        error(format("bad argument #1 to 'select' (number expected, got %s)", n and type(n) or "no value"), 2)
    end

    if n == "#" then
        return arg.n
    elseif n == 0 or n > MAXN then
        error("bad argument #1 to 'select' (index out of range)", 2)
    elseif n == 1 then
        return unpack(arg)
    end

    if n < 0 then
        n = arg.n + n + 1
    end

    for i = 1, n - 1 do
        table.remove(arg, 1)
    end

    return unpack(arg)
end

-- ============================================================
-- 2. 数学扩展
-- ============================================================
math.fmod = math.mod
math.huge = 1 / 0

local huge = math.huge

function math.modf(i)
    i = type(i) ~= "number" and tonumber(i) or i
    if type(i) ~= "number" then
        error(format("bad argument #1 to 'modf' (number expected, got %s)", i and type(i) or "no value"), 2)
    end

    if i == 0 then
        return i, i
    elseif abs(i) == huge then
        return i, i > 0 and 0 or -0
    end

    local int = i > 0 and floor(i) or ceil(i)
    return int, i - int
end

function math.cosh(i)
    i = type(i) ~= "number" and tonumber(i) or i
    if type(i) ~= "number" then
        error(format("bad argument #1 to 'cosh' (number expected, got %s)", i and type(i) or "no value"), 2)
    end

    if i < 0 then i = -i end
    if i > 21 then return exp(i) / 2 end
    return (exp(i) + exp(-i)) / 2
end

function math.sinh(i)
    i = type(i) ~= "number" and tonumber(i) or i
    if type(i) ~= "number" then
        error(format("bad argument #1 to 'sinh' (number expected, got %s)", i and type(i) or "no value"), 2)
    end

    local neg
    if i < 0 then i = -i; neg = true end

    local x
    if i > 21 then
        x = exp(i) / 2
    else
        x = (exp(i) - exp(-i)) / 2
    end

    if neg then x = -x end
    return x
end

function math.tanh(i)
    i = type(i) ~= "number" and tonumber(i) or i
    if type(i) ~= "number" then
        error(format("bad argument #1 to 'tanh' (number expected, got %s)", i and type(i) or "no value"), 2)
    end

    if i == 0 then return i end

    local x = abs(i)
    if x > 21 then
        return i < 0 and -1 or 1
    end

    local s = exp(2 * x)
    x = 1 - 2 / (s + 1)
    if i < 0 then x = -x end
    return x
end

-- ============================================================
-- 3. 字符串扩展
-- ============================================================

-- 拼接
function string.join(delimiter, ...)
    if type(delimiter) ~= "string" and type(delimiter) ~= "number" then
        error(format("bad argument #1 to 'join' (string expected, got %s)", delimiter and type(delimiter) or "no value"), 2)
    end
    if arg.n == 0 then return "" end
    return concat(arg, delimiter)
end
strjoin = string.join

-- 匹配（1.12 只有 find，这里封装 match）
function string.match(str, pattern, index)
    if type(str) ~= "string" and type(str) ~= "number" then
        error(format("bad argument #1 to 'match' (string expected, got %s)", str and type(str) or "no value"), 2)
    elseif type(pattern) ~= "string" and type(pattern) ~= "number" then
        error(format("bad argument #2 to 'match' (string expected, got %s)", pattern and type(pattern) or "no value"), 2)
    end

    local i1, i2, match = find(str, pattern, index)
    if not match and i2 and i2 >= i1 then
        return sub(str, i1, i2)
    end
    return match
end
strmatch = string.match

-- 反转
function string.reverse(str)
    if type(str) ~= "string" and type(str) ~= "number" then
        error(format("bad argument #1 to 'reverse' (string expected, got %s)", str and type(str) or "no value"), 2)
    end

    local size = len(str)
    if size > 1 then
        local reversed = ""
        for i = size, 1, -1 do
            reversed = reversed .. sub(str, i, i)
        end
        return reversed
    end
    return str
end
strrev = string.reverse

-- 去首尾空格
function string.trim(str)
    if type(str) ~= "string" and type(str) ~= "number" then
        error(format("bad argument #1 to 'trim' (string expected, got %s)", str and type(str) or "no value"), 2)
    end
    if type(str) == "number" then
        return tostring(str)
    end
    local result = gsub(str, "^%s*(.-)%s*$", "%1")
    return result
end
strtrim = string.trim

-- 分割
function string.split(subject, delimiter, trim)
    if not subject then return nil end
    local fields = {}
    local start = 1

    repeat
        local b, e = find(subject, delimiter, start)
        if b == nil then
            local s = sub(subject, start)
            table.insert(fields, trim and strtrim(s) or s)
            return fields
        end
        if b > 1 then
            local s = sub(subject, start, b - 1)
            table.insert(fields, trim and strtrim(s) or s)
        else
            table.insert(fields, "")
        end
        start = e + 1
    until false
end
strsplit = string.split

-- gmatch 兼容
string.gmatch = string.gfind
gmatch = string.gfind

-- ============================================================
-- 4. 表扩展
-- ============================================================
function table.maxn(t)
    if type(t) ~= "table" then
        error(format("bad argument #1 to 'maxn' (table expected, got %s)", t and type(t) or "no value"), 2)
    end

    local maxn = 0
    local i = next(t)
    while i do
        if type(i) == "number" and i > maxn then
            maxn = i
        end
        i = next(t, i)
    end
    return maxn
end

-- ============================================================
-- 5. 打印系统
-- ============================================================
local LOCAL_ToStringAllTemp = {}

function tostringall(...)
    local n = arg.n
    if n == 0 then return end
    if n == 1 then return tostring(arg[1]) end
    if n == 2 then return tostring(arg[1]), tostring(arg[2]) end
    if n == 3 then return tostring(arg[1]), tostring(arg[2]), tostring(arg[3]) end

    local needfix
    for i = 1, n do
        if type(arg[i]) ~= "string" then
            needfix = i
            break
        end
    end
    if not needfix then return unpack(arg) end

    for i = 1, table.getn(LOCAL_ToStringAllTemp) do
        LOCAL_ToStringAllTemp[i] = nil
    end
    for i = 1, needfix - 1 do
        LOCAL_ToStringAllTemp[i] = arg[i]
    end
    for i = needfix, n do
        LOCAL_ToStringAllTemp[i] = tostring(arg[i])
    end
    return unpack(LOCAL_ToStringAllTemp)
end

local LOCAL_PrintHandler = function(...)
    DEFAULT_CHAT_FRAME:AddMessage(strjoin(" ", tostringall(unpack(arg))))
end

function setprinthandler(func)
    if type(func) ~= "function" then
        error("Invalid print handler")
    end
    LOCAL_PrintHandler = func
end

function getprinthandler()
    return LOCAL_PrintHandler
end

local function print_inner(...)
    local ok, err = pcall(LOCAL_PrintHandler, unpack(arg))
    if not ok then
        local func = geterrorhandler()
        func(err)
    end
end

function print(...)
    pcall(print_inner, unpack(arg))
end

SLASH_PRINT1 = "/print"
SlashCmdList["PRINT"] = print

-- ============================================================
-- 6. 常用工具
-- ============================================================
function clamp(x, min, max)
    if type(x) == "number" and type(min) == "number" and type(max) == "number" then
        return x < min and min or x > max and max or x
    end
    return x
end

function Round(input, places)
    if not places then places = 0 end
    if type(input) == "number" and type(places) == "number" then
        local pow = 1
        for i = 1, places do pow = pow * 10 end
        return floor(input * pow + 0.5) / pow
    end
end

-- 生成 |cffRRGGBB 颜色码（r,g,b 为 0~1 浮点）
function HexColors(r, g, b)
    if not r then return "|cffFFFFFF" end

    if type(r) == "table" then
        if r.r then
            r, g, b = r.r, r.g, r.b
        else
            r, g, b = unpack(r)
        end
    end

    return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- 扩展检测
function CheckSuperWow()
    return SUPERWOW_STRING and true or false
end

function CheckUnitXP_SP3()
    return pcall(UnitXP, "nop", "nop")
end