local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')

local M = {}

function M.repair()
  local choice =
    vim.fn.confirm('Repair all worktrees or select specific?', '&All\n&Specific\n&Cancel', 1)

  if choice == 3 or choice == 0 then
    return notification.warn('Repair canceled')
  end

  if choice == 1 then
    local result = worktree.repair()
    if result.success then
      local output = table.concat(result.stdout, '\n')
      if #output > 0 then
        notification.info('Repair completed:\n' .. output)
      else
        notification.info('No repairs needed')
      end
    else
      notification.error('Repair failed: ' .. table.concat(result.stderr, '\n'))
    end
  else
    input.select_worktree({
      prompt = 'Select worktree to repair:',
      include_current = true,
    }, function(selected)
      if not selected then
        return notification.warn('No worktree selected')
      end

      local result = worktree.repair({ paths = { selected.path } })

      if result.success then
        notification.info('Repaired worktree: ' .. selected.path)
      else
        notification.error('Failed to repair: ' .. table.concat(result.stderr, '\n'))
      end
    end)
  end
end

return M
