local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local refs = require('worktrees.lib.git.refs')
local git = require('worktrees.lib.git')
local worktree = require('worktrees.lib.git.worktree')
local branch = require('worktrees.lib.git.branch')
local actions = require('worktrees.actions.shared')

local M = {}

-- Validation helpers
local function validate_branch_name(branch_name)
  return branch_name and branch_name:gsub('%s+', '') ~= ''
end

local function get_branch_name()
  local name = input.get_user_input('Branch Name', { strip_spaces = true })
  if not validate_branch_name(name) then
    notification.warn('Invalid branch name')
    return nil
  end
  return name
end

-- Path handling
local function calculate_worktree_path(branch_name)
  local is_bare = git.is_bare()
  local base_path = is_bare and vim.uv.cwd() or vim.fs.normalize(git.root() .. '/..')
  return vim.fs.normalize(base_path .. '/' .. branch_name)
end

-- Directory checks
local function handle_existing_path(path)
  if vim.fn.isdirectory(path) ~= 1 then
    return true
  end

  -- Is existing worktree
  if #worktree.list({ cwd = path }) > 0 then
    actions.switch_to_worktree(path)
    return false
  end

  if not input.get_confirmation('Path exists - overwrite?', { default = 2 }) then
    notification.warn('Worktree creation canceled')
    return false
  end

  return true
end

-- Worktree creation
local function show_creation_error(result)
  notification.error(
    'Failed to create worktree: ' .. (table.concat(result.stderr, '\n') or 'unknown error')
  )
end

local function create_from_existing_branch(path, branch_name)
  local result = worktree.add(path, {
    commitish = branch_name,
  })
  if result.success then
    local previous_path = vim.uv.cwd()
    actions.switch_to_worktree(path)
    actions.emit_event('Created', {
      branch = branch_name,
      path = path,
      previous_path = previous_path,
    })
  else
    show_creation_error(result)
  end
end

local function set_upstream_tracking(ref, path)
  local result = branch.set_upstream(ref, { cwd = path })
  if not result.success then
    notification.warn(
      'Could not set upstream tracking: ' .. (table.concat(result.stderr, '\n') or 'unknown error')
    )
  end
end

local function create_new_worktree(path, branch_name, ref)
  local args = { 'worktree', 'add' }
  if ref ~= 'HEAD' then
    table.insert(args, '-b')
    table.insert(args, branch_name)
  end
  table.insert(args, path)
  if ref and ref ~= 'HEAD' then
    table.insert(args, ref)
  end

  local result = git.run({ args = args })

  if result.success then
    local previous_path = vim.uv.cwd()
    actions.switch_to_worktree(path)
    actions.emit_event('Created', {
      branch = branch_name,
      path = path,
      previous_path = previous_path,
      upstream = ref and ref:match('^origin/') and ref or nil,
    })

    if ref and ref:match('^origin/') then
      set_upstream_tracking(ref, path)
    end
  else
    show_creation_error(result)
  end
end

-- Main workflow
function M.add()
  local branch_name = get_branch_name()
  if not branch_name then
    return
  end

  local path = calculate_worktree_path(branch_name)

  if not handle_existing_path(path) then
    return
  end

  local existing_branches = refs.list_branches()
  if vim.tbl_contains(existing_branches, branch_name) then
    create_from_existing_branch(path, branch_name)
  else
    input.select_ref({
      prompt = 'Select base reference for new branch:',
      include_heads = true,
      include_remotes = true,
    }, function(selected)
      if not selected then
        notification.warn('Creation canceled: No reference selected')
        return
      end
      create_new_worktree(path, branch_name, selected)
    end)
  end
end

return M
