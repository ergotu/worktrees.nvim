local M = {}

---@param s string String to split
---@param sep string Separator pattern
---@return string[] List of substrings
local function split_string(s, sep)
  local fields = {}
  local pattern = string.format('([^%s]+)', sep)
  local _ = s:gsub(pattern, function(c)
    fields[#fields + 1] = c
  end)
  return fields
end

---@alias WorktreeBlock string[] List of lines in a worktree entry block

---@param raw_output string[] Raw output from `git worktree list --porcelain`
---@return WorktreeBlock[]|nil Parsed worktree blocks
local function parse_worktree_blocks(raw_output)
  if not raw_output then
    return nil
  end

  local blocks = {}
  local current_block = {}

  for _, line in ipairs(raw_output) do
    if line == '' then
      if #current_block > 0 then
        table.insert(blocks, current_block)
        current_block = {}
      end
    else
      table.insert(current_block, line)
    end
  end

  if #current_block > 0 then
    table.insert(blocks, current_block)
  end

  return blocks
end

---@class WorktreeEntry
---@field path string Path to worktree
---@field folder string Last directory component of path
---@field sha? string HEAD SHA
---@field branch? string Current branch name
---@field is_bare boolean Whether this is a bare repository

---@param block WorktreeBlock Worktree data block
---@return WorktreeEntry Parsed worktree entry
local function parse_worktree_block(block)
  local entry = { is_bare = false }

  for _, line in ipairs(block) do
    local parts = split_string(line, ' ')
    local key = parts[1]

    local handlers = {
      worktree = function()
        entry.path = parts[2]
        local path_parts = split_string(entry.path, '/')
        entry.folder = path_parts[#path_parts]
      end,
      HEAD = function()
        entry.sha = parts[2]
      end,
      branch = function()
        local branch_parts = split_string(parts[2], '/')
        entry.branch = branch_parts[#branch_parts]
      end,
      bare = function()
        entry.is_bare = true
      end,
    }

    local handler = handlers[key]
    if handler then
      handler()
    end
  end

  return entry
end

---Parse output from `git worktree list --porcelain`
---@param raw_output string[]|nil Raw command output
---@return WorktreeEntry[]|nil List of parsed worktree entries
function M.parse_worktrees(raw_output)
  local blocks = parse_worktree_blocks(raw_output)
  if not blocks then
    return nil
  end

  local trees = {}
  for _, block in ipairs(blocks) do
    local entry = parse_worktree_block(block)
    if not entry.is_bare then
      table.insert(trees, entry)
    end
  end

  return trees
end

return M
