local M = {}

M._default_opts = {
  level = vim.log.levels.WARN,
}

function M.setup(opts)
  if opts == nil then
    return
  end

  M.values = vim.tbl_deep_extend('force', M._default_opts, opts)
end

return M
