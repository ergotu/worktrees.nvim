local config = require('worktrees.config')
local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local refs = require('worktrees.lib.git.refs')
local git = require('worktrees.lib.git')
local worktree = require('worktrees.lib.git.worktree')
local branch = require('worktrees.lib.git.branch')
local M = {}

---@param opts? ConfigOpts
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command('WorktreeAdd', function()
    M.add()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeSwitch', function()
    M.switch()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeRemove', function()
    M.remove()
  end, { nargs = 0 })
end

local function switch(path)
  if not path then
    return
  end
  if path == vim.uv.cwd() then
    return notification.warn('Already in the requested worktree')
  end

  vim.schedule(function()
    vim.cmd('cd ' .. path)
    vim.cmd('clearjumps')
    notification.info('Switched to worktree: ' .. path)
  end)
end

local function get_and_validate_branch_name()
  local branch_name = input.get_user_input('Branch Name', { strip_spaces = true })
  if not branch_name or branch_name == '' then
    notification.warn('No branch name provided')
    return nil
  end
  return branch_name
end

local function get_worktree_path(branch_name, is_bare, git_root)
  local base_path = is_bare and vim.uv.cwd() or vim.fs.normalize(git_root .. '/..')
  return base_path .. '/' .. branch_name
end

local function handle_existing_directory(worktree_path)
  if vim.fn.isdirectory(worktree_path) == 1 then
    local is_worktree = #worktree.list({ cwd = worktree_path }) > 0
    if is_worktree then
      switch(worktree_path)
      return false
    end

    if not input.get_confirmation('Path exists - overwrite?', { default = 2 }) then
      notification.warn('Worktree creation canceled')
      return false
    end
  end
  return true
end

local function branch_exists(branch_name, existing_branches)
  return vim.tbl_contains(existing_branches, branch_name)
end

local function create_existing_branch_worktree(worktree_path, branch_name)
  local result = worktree.add(worktree_path, branch_name)
  if result.success then
    switch(worktree_path)
  else
    notification.error(
      ('Failed to create worktree: %s'):format(table.concat(result.stderr, '\n') or 'unknown error')
    )
  end
end

local function create_worktree_and_set_upstream(worktree_path, branch_name, ref)
  local result = worktree.add(worktree_path, ref, { branch = branch_name })

  if not result.success then
    notification.error(
      ('Failed to create worktree: %s'):format(table.concat(result.stderr, '\n') or 'unknown error')
    )
    return
  end

  -- Only set upstream if creating from remote reference
  if ref:match('^origin/') then
    local upstream_result = branch.set_upstream(branch_name, { cwd = worktree_path })

    if not upstream_result.success then
      notification.warn(
        ('Could not set upstream tracking: %s'):format(
          table.concat(upstream_result.stderr, '\n') or 'unknown error'
        )
      )
    end
  end

  switch(worktree_path)
end

local function select_base_reference_and_create(worktree_path, branch_name)
  input.select_ref({
    prompt = 'Select base reference for new branch:',
    include_heads = true,
    include_remotes = true,
  }, function(selected)
    if not selected then
      notification.warn('No reference selected')
      return
    end
    create_worktree_and_set_upstream(worktree_path, branch_name, selected)
  end)
end

function M.add()
  local branch_name = get_and_validate_branch_name()
  if not branch_name then
    return
  end

  local existing_branches = refs.list_branches()
  local is_existing_branch = branch_exists(branch_name, existing_branches)
  local worktree_path = get_worktree_path(branch_name, git.is_bare(), git.root())

  if not handle_existing_directory(worktree_path) then
    return
  end

  if is_existing_branch then
    create_existing_branch_worktree(worktree_path, branch_name)
  else
    select_base_reference_and_create(worktree_path, branch_name)
  end
end

function M.switch()
  input.select_worktree({}, function(selected)
    switch(selected.path)
  end)
end

function M.remove()
  -- Forward declare these local functions
  local perform_remove, handle_removal_result

  function handle_removal_result(selected, force, result)
    if result.success then
      notification.info('Removed worktree: ' .. selected.path)
      return
    end

    if not force then
      notification.error(
        ('Failed to remove worktree: %s'):format(
          table.concat(result.stderr, '\n') or 'unknown error'
        )
      )
      local attempt_force = input.get_confirmation('Attempt forced removal?', { default = 2 })
      if attempt_force then
        perform_remove(selected, true)
      end
    else
      notification.error(
        ('Force removal failed: %s'):format(table.concat(result.stderr, '\n') or 'unknown error')
      )
    end
  end

  function perform_remove(selected, force)
    worktree.remove(selected.path, {
      force = force,
      callback = function(result)
        handle_removal_result(selected, force, result)
      end,
    })
  end

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
