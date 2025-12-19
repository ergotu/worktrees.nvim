local M = {}

---@alias PathStrategy 'sibling'|'nested'|'custom'

---@class PathStrategyConfig
---@field type PathStrategy
---@field custom? fun(branch: string, root: string): string

---@class BufferBehaviorConfig
---@field mirror boolean Mirror buffers when switching
---@field preserve_layout boolean Preserve window layout
---@field auto_delete_old boolean Delete old buffers after mirroring

---@class TemplateConfig
---@field base_ref? string Base reference for template
---@field path_prefix? string Path prefix to prepend
---@field path_suffix? string Path suffix to append
---@field auto_track? boolean Auto-track upstream
---@field hooks? { before_create?: fun(branch: string, path: string), after_create?: fun(branch: string, path: string) }

---@class RecentsConfig
---@field enabled boolean Enable recent tracking
---@field max_count integer Maximum recent worktrees to track

---@class CleanupConfig
---@field suggest_stale boolean Suggest cleanup of stale worktrees
---@field stale_days integer Days before worktree considered stale

---@class KeymapsConfig
---@field enable boolean Enable default keymaps
---@field prefix string Keymap prefix (e.g., '<leader>gw')
---@field add? string Keymap for add (appended to prefix)
---@field switch? string Keymap for switch
---@field remove? string Keymap for remove
---@field lock? string Keymap for lock
---@field unlock? string Keymap for unlock
---@field move? string Keymap for move
---@field repair? string Keymap for repair
---@field prune? string Keymap for prune

---@class HooksConfig
---@field before_switch? fun(path: string, previous_path: string)
---@field after_switch? fun(path: string, previous_path: string)
---@field before_create? fun(branch: string, path: string)
---@field after_create? fun(branch: string, path: string)
---@field before_remove? fun(path: string)
---@field after_remove? fun(path: string)

---@class ConfigOpts
---@field level? integer Notification log level
---@field path_strategy? PathStrategy|PathStrategyConfig Path generation strategy
---@field default_base_ref? string Default base reference for new branches
---@field auto_track_upstream? boolean Auto-track upstream for remote branches
---@field buffer_behavior? BufferBehaviorConfig Buffer handling configuration
---@field templates? table<string, TemplateConfig> Named worktree templates
---@field aliases? table<string, string> Branch name aliases
---@field recents? RecentsConfig Recent worktree tracking
---@field cleanup? CleanupConfig Cleanup suggestions
---@field keymaps? KeymapsConfig Default keymaps configuration
---@field hooks? HooksConfig Lifecycle hooks

---Helper to normalize path_strategy
---@param strategy PathStrategy|PathStrategyConfig
---@return PathStrategyConfig
local function normalize_path_strategy(strategy)
  if type(strategy) == 'string' then
    return { type = strategy }
  end
  return strategy
end

---@type ConfigOpts
M._default_opts = {
  level = vim.log and vim.log.levels and vim.log.levels.INFO or 2,
  path_strategy = 'sibling',
  default_base_ref = 'HEAD',
  auto_track_upstream = true,
  buffer_behavior = {
    mirror = true,
    preserve_layout = true,
    auto_delete_old = true,
  },
  templates = {},
  aliases = {},
  recents = {
    enabled = false,
    max_count = 10,
  },
  cleanup = {
    suggest_stale = false,
    stale_days = 30,
  },
  keymaps = {
    enable = false,
    prefix = '<leader>gw',
    add = 'a',
    switch = 's',
    remove = 'd',
    lock = 'l',
    unlock = 'u',
    move = 'm',
    repair = 'r',
    prune = 'p',
  },
  hooks = {},
}

-- Helper for table deep extend (works with or without vim API)
local function deep_extend(...)
  if vim.tbl_deep_extend then
    return vim.tbl_deep_extend(...)
  end
  -- Fallback for test environments with proper deep merging
  local behavior = select(1, ...)
  local result = {}

  for i = 2, select('#', ...) do
    local t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        if type(v) == 'table' and type(result[k]) == 'table' then
          -- Recursively merge nested tables
          if behavior == 'force' then
            result[k] = deep_extend(behavior, result[k], v)
          else
            -- For 'error' or 'keep', vim.tbl_deep_extend would check for conflicts
            -- For simplicity in tests, we'll just do force merge
            result[k] = deep_extend('force', result[k], v)
          end
        else
          -- Overwrite with new value
          result[k] = v
        end
      end
    end
  end
  return result
end

-- Initialize with defaults
M.values = deep_extend('force', {}, M._default_opts)
M.values.path_strategy = normalize_path_strategy(M.values.path_strategy)

---@param opts? ConfigOpts
function M.setup(opts)
  opts = opts or {}

  -- Normalize path_strategy if provided
  if opts.path_strategy then
    opts.path_strategy = normalize_path_strategy(opts.path_strategy)
  end

  M.values = deep_extend('force', M._default_opts, opts)
  M.values.path_strategy = normalize_path_strategy(M.values.path_strategy)
end

return M
