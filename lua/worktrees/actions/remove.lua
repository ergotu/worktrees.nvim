local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')
local actions = require('worktrees.actions.shared')

local M = {}

local function perform_remove(selected, force)
  local result = worktree.remove(selected.path, { force = force }):wait()

  if result.success then
    notification.info('Removed worktree: ' .. selected.path)
    actions.emit_event('Removed', { path = selected.path })
  else
    if not force then
      notification.error(
        ('Failed to remove worktree: %s'):format(
          table.concat(result.stderr, '\n') or 'unknown error'
        )
      )
      local attempt_force = input.get_confirmation('Use --force?', { default = 2 })
      if attempt_force then
        perform_remove(selected, true)
      end
    else
      notification.error(
        ('Force removal failed: %s'):format(table.concat(result.stderr, '\n') or 'unknown error')
      )
    end
  end
end

function M.remove()
  local function confirm_removal(selected)
    return input.get_confirmation(('Delete worktree at %s?'):format(selected.path), { default = 2 })
  end

  local function validate_selection(selected)
    if not selected then
      return false
    end
    if selected.path == vim.uv.cwd() then
      notification.warn('Cannot remove current worktree')
      return false
    end
    return true
  end

  input.select_worktree({
    prompt = 'Select worktree to remove:',
    include_current = false,
  }, function(selected)
    if not validate_selection(selected) then
      return
    end
    if not confirm_removal(selected) then
      return
    end

    perform_remove(selected, false)
  end)
end

return M
