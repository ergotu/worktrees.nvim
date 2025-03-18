local notification = require('worktrees.lib.notification')
local M = {}

---@class GetUserInputOpts
---@field strip_spaces? boolean Replace spaces with dashes
---@field default? string Default value
---@field completion? string Completion type
---@field separator? string Prompt separator
---@field cancel? string Cancel return value
---@field prepend? string Text to prepend to input

---Normalize and validate user input
---@param input string
---@param opts GetUserInputOpts
---@return string?
local function process_input(input, opts)
  if input == opts.cancel then
    return nil
  end

  if opts.strip_spaces then
    input = input:gsub('%s+', '-')
  end

  return #input > 0 and input or nil
end

---Smart input preparation with proper feedkeys handling
---@param prepend string
local function prepare_input(prepend)
  if prepend and prepend ~= '' then
    local keys = vim.api.nvim_replace_termcodes(prepend, true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
  end
end

---@param prompt string
---@param opts GetUserInputOpts
---@return string?
function M.get_user_input(prompt, opts)
  opts = vim.tbl_deep_extend('force', {
    strip_spaces = false,
    separator = ': ',
    cancel = '',
  }, opts or {})

  local full_prompt = prompt .. opts.separator

  vim.cmd.redraw({ bang = true })
  prepare_input(opts.prepend or '')
  local input_result = vim.fn.input({
    prompt = full_prompt,
    default = opts.default,
    completion = opts.completion,
    cancelreturn = opts.cancel,
  })

  return process_input(input_result, opts)
end

---@class ConfirmationOpts
---@field values? string[]
---@field default? integer
---@field ok_value? integer

---@param msg string
---@param options? ConfirmationOpts
---@return boolean
function M.get_confirmation(msg, options)
  local opts = vim.tbl_extend('force', {
    values = { '&Yes', '&No' },
    default = 1,
    ok_value = 1,
  }, options or {})

  local choice = vim.fn.confirm(msg, table.concat(opts.values, '\n'), opts.default)
  return choice == opts.ok_value
end

---@class GenericSelectorOpts
---@field prompt string
---@field fetcher fun(): any[] | nil  -- Function to retrieve items
---@field formatter fun(item: any): string  -- Format individual items
---@field no_items_msg? string  -- Message when no items found
---@field allow_nil? boolean  -- Allow returning nil selection

---Generic selector component
---@param opts GenericSelectorOpts
---@param callback fun(selected: any?)
function M.select(opts, callback)
  local items = opts.fetcher()
  if not items or vim.tbl_isempty(items) then
    if opts.no_items_msg then
      notification.warn(opts.no_items_msg)
    end
    return callback(opts.allow_nil and nil or nil)
  end

  local formatted = vim.tbl_map(opts.formatter, items)
  vim.ui.select(formatted, {
    prompt = opts.prompt,
    format_item = function(item)
      return item
    end,
  }, function(selected, idx)
    callback(selected and items[idx] or nil)
  end)
end

---@class RefSelectorOpts
---@field prompt? string
---@field format? fun(item: any): string
---@field include_heads? boolean
---@field include_remotes? boolean

---@param opts RefSelectorOpts
---@param callback fun(selected: string?)
function M.select_ref(opts, callback)
  local refs = require('worktrees.lib.git.refs')
  opts = vim.tbl_deep_extend('force', {
    prompt = 'Select git reference:',
    format = function(item)
      local icon = ({
        branch = '󰘬 ',
        head = '󰥨 ',
        tag = '󰓻 ',
      })[item.type] or '󰡀 '
      return string.format('%s %s', icon, item.name)
    end,
    include_heads = true,
    include_remotes = true,
  }, opts or {})

  M.select({
    prompt = opts.prompt,
    fetcher = function()
      -- Collect reference types
      local items = {}
      for _, branch in ipairs(refs.list_local_branches()) do
        table.insert(items, { name = branch, type = 'branch' })
      end
      if opts.include_remotes then
        for _, branch in ipairs(refs.list_remote_branches()) do
          table.insert(items, { name = branch, type = 'branch' })
        end
      end
      if opts.include_heads then
        for _, branch in ipairs(refs.heads()) do
          table.insert(items, { name = branch, type = 'head' })
        end
      end
      for _, tag in ipairs(refs.list_tags()) do
        table.insert(items, { name = tag, type = 'tag' })
      end
      return items
    end,
    formatter = opts.format,
    no_items_msg = 'No git references available',
  }, function(selected)
    callback(selected and selected.name or nil)
  end)
end

---@class WorktreeSelectorOpts
---@field prompt? string
---@field format? fun(wt: WorktreeEntry): string

---@param opts WorktreeSelectorOpts
---@param callback fun(selected: WorktreeEntry?)
function M.select_worktree(opts, callback)
  local worktree = require('worktrees.lib.git.worktree')
  local parser = require('worktrees.lib.parser')
  opts = vim.tbl_deep_extend('force', {
    prompt = 'Select worktree:',
    format = function(wt)
      local status = wt.is_bare and '󰨎 ' or '󰉋 '
      local branch = wt.branch and string.format('(%s)', wt.branch) or ''
      return string.format('%s %s %s', status, wt.folder, branch)
    end,
  }, opts or {})

  M.select({
    prompt = opts.prompt,
    fetcher = function()
      local raw = worktree.list()
      return parser.parse_worktrees(raw) or {}
    end,
    formatter = opts.format,
    no_items_msg = 'No worktrees available',
  }, callback)
end

return M
