describe('lib.path', function()
  local path
  local config_mock
  local git_mock
  local vim_mock

  before_each(function()
    vim_mock = {
      uv = {
        cwd = function()
          return '/home/user/project'
        end,
      },
      fs = {
        normalize = function(p)
          return p
        end,
      },
    }

    config_mock = {
      values = {
        path_strategy = { type = 'sibling' },
      },
    }

    git_mock = {
      root = function()
        return '/home/user/project'
      end,
      is_bare = function()
        return false
      end,
    }

    _G.vim = vim_mock
    package.loaded['worktrees.config'] = config_mock
    package.loaded['worktrees.lib.git'] = git_mock

    path = require('worktrees.lib.path')
  end)

  after_each(function()
    package.loaded['worktrees.lib.path'] = nil
    _G.vim = nil
  end)

  it('calculates sibling path for regular repo', function()
    config_mock.values.path_strategy = { type = 'sibling' }

    local result = path.calculate_path('feature-branch')

    assert.equals('/home/user/project/../feature-branch', result)
  end)

  it('calculates nested path for regular repo', function()
    config_mock.values.path_strategy = { type = 'nested' }

    local result = path.calculate_path('feature-branch')

    assert.equals('/home/user/project/worktrees/feature-branch', result)
  end)

  it('calculates sibling path for bare repo', function()
    config_mock.values.path_strategy = { type = 'sibling' }
    git_mock.is_bare = function()
      return true
    end

    local result = path.calculate_path('feature-branch')

    assert.equals('/home/user/project/feature-branch', result)
  end)

  it('calculates nested path for bare repo', function()
    config_mock.values.path_strategy = { type = 'nested' }
    git_mock.is_bare = function()
      return true
    end

    local result = path.calculate_path('feature-branch')

    assert.equals('/home/user/project/worktrees/feature-branch', result)
  end)

  it('uses custom function when provided', function()
    config_mock.values.path_strategy = {
      type = 'custom',
      custom = function(branch, root)
        return '/custom/' .. branch
      end,
    }

    local result = path.calculate_path('feature-branch')

    assert.equals('/custom/feature-branch', result)
  end)

  it('errors when custom strategy has no function', function()
    config_mock.values.path_strategy = { type = 'custom' }

    assert.has_error(function()
      path.calculate_path('feature-branch')
    end)
  end)

  it('errors on unknown strategy type', function()
    config_mock.values.path_strategy = { type = 'unknown' }

    assert.has_error(function()
      path.calculate_path('feature-branch')
    end)
  end)
end)
