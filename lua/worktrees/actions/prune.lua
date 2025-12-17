local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local worktree = require('worktrees.lib.git.worktree')
local cleanup = require('worktrees.lib.cleanup')

local M = {}

function M.prune()
  -- Show cleanup suggestions if enabled
  local suggestion = cleanup.suggest()
  if suggestion then
    notification.info(suggestion)
  end

  local dry_result = worktree.prune({ dry_run = true, verbose = true })

  if not dry_result.success then
    return notification.error('Prune check failed: ' .. table.concat(dry_result.stderr, '\n'))
  end

  local output = table.concat(dry_result.stdout, '\n')

  if #output == 0 or output:match('^%s*$') then
    return notification.info('No stale worktree data to prune')
  end

  notification.info('Stale worktree data:\n' .. output)

  if not input.get_confirmation('Prune stale worktree data?', { default = 2 }) then
    return notification.warn('Prune canceled')
  end

  local result = worktree.prune({ verbose = true })

  if result.success then
    notification.info('Pruned stale worktree data')
  else
    notification.error('Prune failed: ' .. table.concat(result.stderr, '\n'))
  end
end

return M
