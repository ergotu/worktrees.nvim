# Task Completion Checklist

When completing a task, ensure the following steps are performed:

## Code Quality
- [ ] **Format code**: Run `stylua .` to format all modified files
- [ ] **Check formatting**: Run `stylua --check .` to verify formatting
- [ ] **Follow style conventions**: 
  - 2-space indentation
  - 100 character column width
  - Single quotes preferred
  - Always use parentheses in function calls
  - Add LuaCATS type annotations

## Testing
- [ ] **Write/update tests**: Add tests in `test/plugin_spec.lua` for new functionality
- [ ] **Run tests**: Execute `busted` to ensure all tests pass
- [ ] **Test with Neovim**: Manually test the plugin in Neovim if applicable

## Documentation
- [ ] **Update README**: If adding new features or changing behavior
- [ ] **Add/update type annotations**: Use LuaCATS format for all public functions
- [ ] **Update configuration docs**: If adding new config options

## Git Workflow
- [ ] **Review changes**: `git diff` to verify modifications
- [ ] **Stage changes**: `git add <files>`
- [ ] **Commit with clear message**: Follow conventional commits format
  - `feat:` for new features
  - `fix:` for bug fixes
  - `refactor:` for refactoring
  - `chore:` for maintenance
  - `docs:` for documentation

## Pre-Push Checklist
- [ ] All tests passing
- [ ] Code formatted with StyLua
- [ ] No linting errors
- [ ] Type annotations added
- [ ] Changes committed with descriptive message
