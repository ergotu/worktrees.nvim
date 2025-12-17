# Suggested Commands

## Testing
```bash
# Run tests using busted
busted

# Or use nlua directly (configured in .busted)
nlua test/plugin_spec.lua
```

## Formatting
```bash
# Format all files with StyLua
stylua .

# Check formatting without modifying files
stylua --check .
```

## Linting
```bash
# StyLua is used for both formatting and linting
stylua --check .
```

## Git Commands
```bash
# Standard git operations
git status
git add .
git commit -m "message"
git push
git pull

# For working with worktrees manually
git worktree list
git worktree add <path> <branch>
git worktree remove <path>
```

## Development Workflow
1. Make changes to Lua files in `lua/worktrees/`
2. Add/update tests in `test/plugin_spec.lua`
3. Format code: `stylua .`
4. Run tests: `busted`
5. Commit changes

## CI/CD
The GitHub Actions workflows automatically:
- Run `stylua --check .` on every push
- Run tests with both stable and nightly Neovim
- Generate documentation from README (on main branch only)
