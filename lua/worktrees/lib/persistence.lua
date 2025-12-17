local M = {}

---Get data directory path
---@return string
local function get_data_dir()
  local data_path = vim.fn.stdpath('data')
  local worktrees_dir = data_path .. '/worktrees.nvim'

  -- Ensure directory exists
  if vim.fn.isdirectory(worktrees_dir) == 0 then
    vim.fn.mkdir(worktrees_dir, 'p')
  end

  return worktrees_dir
end

---Get full path for a data file
---@param filename string
---@return string
local function get_data_file(filename)
  return get_data_dir() .. '/' .. filename
end

---Read JSON data from file
---@param filename string
---@return table|nil
function M.read_json(filename)
  local filepath = get_data_file(filename)

  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local file = io.open(filepath, 'r')
  if not file then
    return nil
  end

  local content = file:read('*a')
  file:close()

  if not content or content == '' then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end

  return decoded
end

---Write JSON data to file
---@param filename string
---@param data table
---@return boolean success
function M.write_json(filename, data)
  local filepath = get_data_file(filename)

  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return false
  end

  local file = io.open(filepath, 'w')
  if not file then
    return false
  end

  file:write(encoded)
  file:close()

  return true
end

---Delete a data file
---@param filename string
---@return boolean success
function M.delete(filename)
  local filepath = get_data_file(filename)

  if vim.fn.filereadable(filepath) == 0 then
    return true -- Already doesn't exist
  end

  return vim.fn.delete(filepath) == 0
end

return M
