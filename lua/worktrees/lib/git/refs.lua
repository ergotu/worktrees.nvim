local git = require('worktrees.lib.git')
local util = require('worktrees.lib.util')

---@class ForEachRefOpts
---@field format? string
---@field points_at? string
---@field merged? string
---@field sort? string
---@field patterns? string[]
---@field cwd? string

local M = {}

---@param opts? ForEachRefOpts
---@return GitResult
function M.for_each_ref(opts)
  opts = opts or {}
  local args = { 'for-each-ref' }

  if opts.format then
    table.insert(args, '--format=' .. opts.format)
  end
  if opts.points_at then
    table.insert(args, '--points-at=' .. opts.points_at)
  end
  if opts.merged then
    table.insert(args, '--merged=' .. opts.merged)
  end
  if opts.sort then
    table.insert(args, '--sort=' .. opts.sort)
  end

  if opts.patterns then
    for _, pattern in ipairs(opts.patterns) do
      table.insert(args, pattern)
    end
  end

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---@type fun(format?: string, sortby?: string, filter?: string[]): string[]
local refs = util.memoize(function(format, sortby, filter)
  return M.for_each_ref({
    format = format or '%(refname)',
    sort = sortby or '-committerdate',
    patterns = filter or {},
  }).stdout
end)

---@param namespaces? string[] Git ref namespaces to filter (e.g. '^refs/heads/')
---@param format? string Format string for for-each-ref
---@param sortby? string Sort key for references
---@return string[] List of simplified reference names
function M.list(namespaces, format, sortby)
  local patterns = util.map(namespaces or {}, function(namespace)
    -- Remove leading '^' from namespace patterns
    return namespace:sub(2, -1)
  end)

  return util.map(refs(format, sortby, patterns), function(full_ref)
    -- Extract short name from full reference path
    local ref, _ = full_ref:gsub('^refs/[^/]*/', '', 1)
    return ref
  end)
end

---@return string[] List of tag names
function M.list_tags()
  return M.list({ '^refs/tags/' })
end

---@return string[] List of all branch names (local and remote)
function M.list_branches()
  return util.merge(M.list_local_branches(), M.list_remote_branches())
end

---@return string[] List of local branch names
function M.list_local_branches()
  return M.list({ '^refs/heads/' })
end

---@param remote? string Filter remote branches by specific remote
---@return string[] List of remote branch names
function M.list_remote_branches(remote)
  local remote_branches = M.list({ '^refs/remotes/' })

  if not remote then
    return remote_branches
  end

  local remote_prefix = '^' .. vim.pesc(remote) .. '/'
  return vim.tbl_filter(function(branch)
    return branch:match(remote_prefix)
  end, remote_branches)
end

M.heads = util.memoize(function()
  local heads = { 'HEAD', 'ORIG_HEAD', 'FETCH_HEAD', 'MERGE_HEAD', 'CHERRY_PICK_HEAD' }
  local present = {}

  for _, head in ipairs(heads) do
    local result = git.run({ args = { 'rev-parse', '--verify', '--quiet', head } })
    if result.success then
      table.insert(present, head)
    end
  end

  return present
end)

return M
