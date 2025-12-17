local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')
local shared = require('worktrees.actions.shared')

local M = {}

function M.move()
  input.select_worktree({
    prompt = 'Select worktree to move:',
    include_current = true,
  }, function(selected)
    if not selected then
      return notification.warn('No worktree selected')
    end

    local destination = input.get_user_input('New path', {
      default = selected.path,
      strip_spaces = false,
    })

    if not destination or destination == '' or destination == selected.path then
      return notification.warn('Move canceled')
    end

    if vim.fn.isdirectory(destination) == 1 then
      return notification.error('Destination already exists: ' .. destination)
    end

    local result = worktree.move(selected.path, destination)

    if result.success then
      notification.info('Moved worktree to: ' .. destination)

      if selected.path == vim.uv.cwd() then
        vim.cmd('cd ' .. vim.fn.fnameescape(destination))
      end

      shared.emit_event('Moved', {
        old_path = selected.path,
        new_path = destination,
        path = destination,
      })
    else
      notification.error('Failed to move: ' .. table.concat(result.stderr, '\n'))
    end
  end)
end

return M
