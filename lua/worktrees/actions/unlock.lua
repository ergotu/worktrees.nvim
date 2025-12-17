local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')

local M = {}

function M.unlock()
  input.select_worktree({
    prompt = 'Select worktree to unlock:',
    include_current = true,
  }, function(selected)
    if not selected then
      return notification.warn('No worktree selected')
    end

    local result = worktree.unlock(selected.path)

    if result.success then
      notification.info('Unlocked worktree: ' .. selected.path)
    else
      notification.error('Failed to unlock: ' .. table.concat(result.stderr, '\n'))
    end
  end)
end

return M
