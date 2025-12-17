local persistence = require('worktrees.lib.persistence')
local config = require('worktrees.config')

local M = {}
local RECENTS_FILE = 'recents.json'

---@class RecentEntry
---@field path string
---@field branch string|nil
---@field last_accessed integer Timestamp

---Get recent worktrees
---@return RecentEntry[]
function M.get()
  if not config.values.recents.enabled then
    return {}
  end

  local data = persistence.read_json(RECENTS_FILE)
  if not data or not data.recents then
    return {}
  end

  return data.recents
end

---Add or update a recent worktree
---@param path string
---@param branch string|nil
function M.add(path, branch)
  if not config.values.recents.enabled then
    return
  end

  local recents = M.get()
  local now = os.time()

  -- Remove if already exists
  recents = vim.tbl_filter(function(entry)
    return entry.path ~= path
  end, recents)

  -- Add to front
  table.insert(recents, 1, {
    path = path,
    branch = branch,
    last_accessed = now,
  })

  -- Limit to max_count
  local max = config.values.recents.max_count
  if #recents > max then
    recents = vim.list_slice(recents, 1, max)
  end

  persistence.write_json(RECENTS_FILE, { recents = recents })
end

---Remove a path from recents
---@param path string
function M.remove(path)
  if not config.values.recents.enabled then
    return
  end

  local recents = M.get()
  recents = vim.tbl_filter(function(entry)
    return entry.path ~= path
  end, recents)

  persistence.write_json(RECENTS_FILE, { recents = recents })
end

---Clear all recents
function M.clear()
  persistence.delete(RECENTS_FILE)
end

return M
