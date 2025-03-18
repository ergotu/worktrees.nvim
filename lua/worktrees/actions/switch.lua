local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local actions = require('worktrees.actions.shared')

local M = {}

function M.switch()
  input.select_worktree({
    format = function(wt)
      return string.format('%s (%s)', wt.folder, wt.branch or 'detached')
    end,
  }, function(selected)
    if not selected then
      return notification.warn('No worktree selected')
    end

    local previous_path = vim.uv.cwd()
    actions.switch_to_worktree(selected.path)

    actions.emit_event('Switched', {
      path = selected.path,
      previous_path = previous_path,
    })
  end)
end

return M
