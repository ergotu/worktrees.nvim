---@class TestHelpers
local M = {}

---Create a mock for vim.system
---@param responses table<string, {code: number, stdout: string, stderr: string}>
---@return function
function M.mock_vim_system(responses)
  return function(cmd, opts, on_exit)
    local cmd_str = table.concat(cmd, ' ')
    local response = responses[cmd_str]

    if not response then
      error('Unexpected git command: ' .. cmd_str)
    end

    local result = {
      code = response.code or 0,
      stdout = response.stdout or '',
      stderr = response.stderr or '',
    }

    if on_exit then
      on_exit(result)
    end

    return result
  end
end

---Create a mock for vim.ui.input
---@param response string|nil The response to return
---@return function
function M.mock_vim_ui_input(response)
  return function(opts, on_confirm)
    on_confirm(response)
  end
end

---Create a mock for vim.ui.select
---@param response any|nil The selected item
---@return function
function M.mock_vim_ui_select(response)
  return function(items, opts, on_choice)
    on_choice(response)
  end
end

---Create a mock for vim.notify
---@return function, table
function M.mock_vim_notify()
  local notifications = {}

  local function mock_notify(msg, level)
    table.insert(notifications, { msg = msg, level = level })
  end

  return mock_notify, notifications
end

---Create a minimal vim global for testing
---@return table
function M.create_vim_mock()
  return {
    log = {
      levels = {
        DEBUG = 0,
        INFO = 1,
        WARN = 2,
        ERROR = 3,
      },
    },
    fn = {
      fnameescape = function(path)
        return path:gsub(' ', '\\ ')
      end,
      isdirectory = function(path)
        return 0
      end,
      filereadable = function(path)
        return 0
      end,
    },
    api = {
      nvim_list_bufs = function()
        return {}
      end,
      nvim_buf_is_valid = function()
        return true
      end,
      nvim_buf_get_name = function()
        return ''
      end,
      nvim_buf_delete = function() end,
      nvim_exec_autocmds = function() end,
      nvim_create_user_command = function() end,
    },
    uv = {
      cwd = function()
        return '/home/user/project'
      end,
    },
    fs = {
      normalize = function(path)
        return path
      end,
    },
    bo = {},
    tbl_deep_extend = function(mode, ...)
      local result = {}
      for i = 1, select('#', ...) do
        local tbl = select(i, ...)
        for k, v in pairs(tbl) do
          result[k] = v
        end
      end
      return result
    end,
    tbl_contains = function(tbl, value)
      for _, v in ipairs(tbl) do
        if v == value then
          return true
        end
      end
      return false
    end,
    cmd = function() end,
    schedule = function(fn)
      fn()
    end,
    inspect = function(tbl)
      -- Simple mock implementation to avoid recursion
      return tostring(tbl)
    end,
  }
end

return M
