# Code Style and Conventions

## Formatting (StyLua Configuration)
From `.stylua.toml`:
- **Column width**: 100 characters
- **Line endings**: Unix (LF)
- **Indent type**: Spaces
- **Indent width**: 2 spaces
- **Quote style**: AutoPreferSingle (prefer single quotes)
- **Call parentheses**: Always (always use parentheses in function calls)

## Lua Conventions
- Use LuaCATS annotations for types (`---@class`, `---@type`, `---@param`, `---@field`)
- Module pattern: return a table `M` with exported functions
- Private/default values prefixed with underscore (e.g., `M._default_opts`)
- Configuration passed via `opts` parameter in `setup()` function

## Naming Conventions
- Module files in lowercase with underscores
- Action modules named after their function (add.lua, remove.lua, switch.lua)
- Library code organized in `lib/` directory
- Git-related functionality in `lib/git/` subdirectory

## Architecture Patterns
- **Separation of concerns**: Actions in `actions/`, libraries in `lib/`, config in `config.lua`
- **Module exports**: Each module returns a table with public functions
- **Configuration**: Centralized in `config.lua` using `vim.tbl_deep_extend`
- **User commands**: Created in main `init.lua` via `vim.api.nvim_create_user_command`

## Type Annotations
Always use LuaCATS annotations:
```lua
---@class ConfigOpts
---@field level integer

---@param opts? ConfigOpts
function M.setup(opts)
  -- ...
end
```
