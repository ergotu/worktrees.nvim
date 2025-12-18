local input = require('worktrees.lib.input')
local notification = require('worktrees.lib.notification')
local refs = require('worktrees.lib.git.refs')
local git = require('worktrees.lib.git')
local worktree = require('worktrees.lib.git.worktree')
local branch = require('worktrees.lib.git.branch')
local shared = require('worktrees.actions.shared')
local config = require('worktrees.config')
local recents = require('worktrees.lib.recents')

local M = {}

-- Validation helpers
local function validate_branch_name(branch_name)
  if not branch_name or branch_name:gsub('%s+', '') == '' then
    return false
  end
  -- Git branch name rules
  if
    branch_name:match('%.%.')
    or branch_name:match('[~^: ?*%[\\]@{]')
    or branch_name:match('^/')
    or branch_name:match('/$')
    or branch_name:match('//')
    or branch_name:match('@$')
  then
    return false
  end
  return true
end

-- Alias expansion
local function expand_alias(branch_name)
  return config.values.aliases[branch_name] or branch_name
end

-- Template matching
local function apply_template(branch_name)
  for pattern, template_config in pairs(config.values.templates) do
    if branch_name:match(pattern) then
      return template_config
    end
  end
  return nil
end

local function get_branch_name()
  local name = input.get_user_input('Branch Name', { strip_spaces = true })
  if not validate_branch_name(name) then
    notification.warn('Invalid branch name')
    return nil
  end
  -- Expand alias
  name = expand_alias(name)
  return name
end

-- Path handling
local function calculate_worktree_path(branch_name)
  local path_module = require('worktrees.lib.path')
  return path_module.calculate_path(branch_name)
end

-- Directory checks
local function handle_existing_path(path)
  if vim.fn.isdirectory(path) ~= 1 then
    return true
  end

  -- Is existing worktree
  if #worktree.list({ cwd = path }) > 0 then
    shared.switch_to_worktree(path)
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
  -- Call before_create hook
  if config.values.hooks.before_create then
    config.values.hooks.before_create(branch_name, path)
  end

  local result = worktree.add(path, {
    commitish = branch_name,
  })
  if result.success then
    local previous_path = vim.uv.cwd()
    shared.switch_to_worktree(path)

    -- Track in recents
    recents.add(path, branch_name)

    shared.emit_event('Created', {
      branch = branch_name,
      path = path,
      previous_path = previous_path,
    })

    -- Call after_create hook
    if config.values.hooks.after_create then
      config.values.hooks.after_create(branch_name, path)
    end
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

local function create_new_worktree(path, branch_name, ref, template)
  template = template or {}

  -- Apply template path transformations
  if template.path_prefix then
    path = vim.fs.dirname(path) .. '/' .. template.path_prefix .. vim.fs.basename(path)
  end
  if template.path_suffix then
    path = path .. template.path_suffix
  end

  -- Use template base_ref if provided
  local base_ref = template.base_ref or ref

  -- Call template before_create hook
  if template.hooks and template.hooks.before_create then
    template.hooks.before_create(branch_name, path)
  end

  -- Call global before_create hook
  if config.values.hooks.before_create then
    config.values.hooks.before_create(branch_name, path)
  end

  local args = { 'worktree', 'add' }
  if base_ref ~= 'HEAD' then
    table.insert(args, '-b')
    table.insert(args, branch_name)
  end
  table.insert(args, path)
  if base_ref and base_ref ~= 'HEAD' then
    table.insert(args, base_ref)
  end

  local result = git.run({ args = args })

  if result.success then
    local previous_path = vim.uv.cwd()
    shared.switch_to_worktree(path)

    local should_track = (
      base_ref
      and base_ref:match('^origin/')
      and config.values.auto_track_upstream
    ) or template.auto_track

    -- Track in recents
    recents.add(path, branch_name)

    shared.emit_event('Created', {
      branch = branch_name,
      path = path,
      previous_path = previous_path,
      upstream = should_track and base_ref or nil,
    })

    if should_track then
      set_upstream_tracking(base_ref, path)
    end

    -- Call template after_create hook
    if template.hooks and template.hooks.after_create then
      template.hooks.after_create(branch_name, path)
    end

    -- Call global after_create hook
    if config.values.hooks.after_create then
      config.values.hooks.after_create(branch_name, path)
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
  local template = apply_template(branch_name)

  if not handle_existing_path(path) then
    return
  end

  local existing_branches = refs.list_branches()
  if vim.tbl_contains(existing_branches, branch_name) then
    create_from_existing_branch(path, branch_name)
  else
    -- If template exists and has base_ref, use it automatically
    if template and template.base_ref then
      create_new_worktree(path, branch_name, template.base_ref, template)
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
        create_new_worktree(path, branch_name, selected, template)
      end)
    end
  end
end

return M
