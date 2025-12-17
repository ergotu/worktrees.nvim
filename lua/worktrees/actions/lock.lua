local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')

local M = {}

function M.lock()
  input.select_worktree({
    prompt = 'Select worktree to lock:',
    include_current = true,
  }, function(selected)
    if not selected then
      return notification.warn('No worktree selected')
    end

    local reason = input.get_user_input('Lock reason (optional, press Enter to skip)', {
      default = '',
      strip_spaces = false,
    })

    local opts = nil
    if reason and #reason > 0 then
      opts = { reason = reason }
    end

    local result = worktree.lock(selected.path, opts)

    if result.success then
      local msg = 'Locked worktree: ' .. selected.path
      if reason and #reason > 0 then
        msg = msg .. ' (reason: ' .. reason .. ')'
      end
      notification.info(msg)
    else
      notification.error('Failed to lock: ' .. table.concat(result.stderr, '\n'))
    end
  end)
end

return M
