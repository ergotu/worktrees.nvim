local config = require('worktrees.config')
local levels = vim.log.levels

local M = {}

---@param message string
---@param level integer
local function create(message, level)
  message = type(message) == 'table' and table.concat(message, '\n') or message
  message = vim.trim(message)

  if level >= config.values.level then
    vim.schedule(function()
      vim.notify(message, level, { title = 'Worktrees' })
    end)
  end
end

---@param message string
function M.error(message)
  create(message, levels.ERROR)
end

---@param message string
function M.warn(message)
  create(message, levels.WARN)
end

---@param message string
function M.info(message)
  create(message, levels.INFO)
end

---@param message string
function M.debug(message)
  create(message, levels.DEBUG)
end

---@param message string
function M.trace(message)
  create(message, levels.TRACE)
end

function M.command_debug(args)
  M.debug('Running command: git ' .. table.concat(args, ' '))
end

return M
