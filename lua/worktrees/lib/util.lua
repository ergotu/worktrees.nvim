local M = {}

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f fun(v: T): U
---@return U[]
function M.map(tbl, f)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

--- Merge multiple 1-dimensional list-like tables into one, preserving order
---@param ... table
---@return table
function M.merge(...)
  local insert = table.insert
  local res = {}
  for _, tbl in ipairs({ ... }) do
    for _, item in ipairs(tbl) do
      insert(res, item)
    end
  end
  return res
end

---Simple timeout function
---@param timeout integer
---@param callback function
---@return uv.uv_timer_t | nil
local function set_timeout(timeout, callback)
  local timer = vim.uv.new_timer()
  if not timer then
    return nil
  end

  timer:start(timeout, 0, function()
    if timer then
      timer:stop()
      timer:close()
    end
    callback()
  end)

  return timer
end

local DEFAULT_TIMEOUT = os.getenv('CI') and 0 or 1000

---Memoize a function's result for a set period of time. Value will be forgotten after specified timeout, or 1 second. Timer resets with each call.
---@param f function Function to memoize
---@param opts table?
---@return function
function M.memoize(f, opts)
  opts = opts or {}

  assert(f, 'Cannot memoize without function')

  local cache = {}
  local timer = {}

  return function(...)
    local cwd = vim.uv.cwd()
    assert(cwd, 'no cwd')

    local key = vim.inspect({ vim.fs.normalize(cwd), ... })

    if cache[key] == nil then
      cache[key] = f(...)
    elseif timer[key] ~= nil then
      timer[key]:stop()
      timer[key]:close()
    end

    timer[key] = set_timeout(opts.timeout or DEFAULT_TIMEOUT, function()
      cache[key] = nil
      timer[key] = nil
    end)

    return cache[key]
  end
end

return M
