local config = require('worktrees.config')
local actions = require('worktrees.actions')

local M = {}

---@param opts? ConfigOpts
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command('WorktreeAdd', function()
    actions.add()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeSwitch', function()
    actions.switch()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeRemove', function()
    actions.remove()
  end, { nargs = 0 })
end

return M
