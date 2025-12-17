local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local shared = require('worktrees.actions.shared')
local config = require('worktrees.config')
local recents = require('worktrees.lib.recents')

local M = {}

---Switch to an existing worktree
function M.switch()
  input.select_worktree({}, function(selected)
    if not selected then
      return notification.warn('No worktree selected')
    end

    local previous_path = vim.uv.cwd()

    -- Call before_switch hook
    if config.values.hooks.before_switch then
      config.values.hooks.before_switch(selected.path, previous_path)
    end

    shared.switch_to_worktree(selected.path)

    -- Track in recents
    recents.add(selected.path, selected.branch)

    shared.emit_event('Switched', {
      path = selected.path,
      previous_path = previous_path,
    })

    -- Call after_switch hook
    if config.values.hooks.after_switch then
      config.values.hooks.after_switch(selected.path, previous_path)
    end
  end)
end

return M
