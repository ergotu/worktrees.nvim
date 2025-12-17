describe('lib.git.init', function()
  local git
  local helpers

  before_each(function()
    -- Setup mock vim global
    helpers = require('test.helpers')
    _G.vim = helpers.create_vim_mock()

    -- Mock vim.system
    _G.vim.system = function(cmd, opts)
      return {
        wait = function()
          return { code = 0, stdout = '', stderr = '' }
        end,
      }
    end

    _G.vim.list_extend = function(a, b)
      local result = {}
      for _, v in ipairs(a) do
        table.insert(result, v)
      end
      for _, v in ipairs(b) do
        table.insert(result, v)
      end
      return result
    end

    _G.vim.split = function(str, sep, opts)
      if str == '' then
        return {}
      end
      local result = {}
      for line in str:gmatch('[^\n]+') do
        table.insert(result, line)
      end
      return result
    end

    -- Reload the module to pick up the mocked vim
    package.loaded['worktrees.lib.git'] = nil
    git = require('worktrees.lib.git')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.lib.git'] = nil
  end)

  describe('run', function()
    it('executes git command successfully', function()
      _G.vim.system = function(cmd, opts)
        assert.are.same({ 'git', 'status' }, cmd)
        return {
          wait = function()
            return { code = 0, stdout = 'On branch main', stderr = '' }
          end,
        }
      end

      local result = git.run({ args = { 'status' } })

      assert.is_true(result.success)
      assert.are.same({ 'On branch main' }, result.stdout)
      assert.are.same({}, result.stderr)
    end)

    it('handles git command failure', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 1, stdout = '', stderr = 'fatal: not a git repository' }
          end,
        }
      end

      local result = git.run({ args = { 'status' } })

      assert.is_false(result.success)
      assert.are.same({}, result.stdout)
      assert.are.same({ 'fatal: not a git repository' }, result.stderr)
    end)

    it('passes cwd option to vim.system', function()
      local passed_opts = nil
      _G.vim.system = function(cmd, opts)
        passed_opts = opts
        return {
          wait = function()
            return { code = 0, stdout = '', stderr = '' }
          end,
        }
      end

      git.run({ args = { 'status' }, cwd = '/tmp/repo' })

      assert.are.equal('/tmp/repo', passed_opts.cwd)
    end)

    it('splits multi-line stdout correctly', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 0, stdout = 'line1\nline2\nline3', stderr = '' }
          end,
        }
      end

      local result = git.run({ args = { 'log' } })

      assert.are.same({ 'line1', 'line2', 'line3' }, result.stdout)
    end)
  end)

  describe('run_async', function()
    it('executes git command asynchronously', function()
      local callback_result = nil

      _G.vim.system = function(cmd, opts, on_exit)
        assert.are.same({ 'git', 'fetch' }, cmd)
        vim.schedule(function()
          on_exit({ code = 0, stdout = 'Fetching origin', stderr = '' })
        end)
      end

      git.run_async({ args = { 'fetch' } }, function(result)
        callback_result = result
      end)

      assert.is_not_nil(callback_result)
      assert.is_true(callback_result.success)
      assert.are.same({ 'Fetching origin' }, callback_result.stdout)
    end)
  end)

  describe('root', function()
    it('returns git root directory', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 0, stdout = '/home/user/repo', stderr = '' }
          end,
        }
      end

      local root = git.root()

      assert.are.equal('/home/user/repo', root)
    end)

    it('returns nil when not in a git repository', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 128, stdout = '', stderr = 'fatal: not a git repository' }
          end,
        }
      end

      local root = git.root()

      assert.is_nil(root)
    end)

    it('passes cwd to git command', function()
      local passed_opts = nil
      _G.vim.system = function(cmd, opts)
        passed_opts = opts
        return {
          wait = function()
            return { code = 0, stdout = '/tmp/other-repo', stderr = '' }
          end,
        }
      end

      git.root('/tmp/other-repo')

      assert.are.equal('/tmp/other-repo', passed_opts.cwd)
    end)
  end)

  describe('is_bare', function()
    it('returns true for bare repository', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 0, stdout = 'true', stderr = '' }
          end,
        }
      end

      local is_bare = git.is_bare()

      assert.is_true(is_bare)
    end)

    it('returns false for non-bare repository', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 0, stdout = 'false', stderr = '' }
          end,
        }
      end

      local is_bare = git.is_bare()

      assert.is_false(is_bare)
    end)

    it('returns false on error', function()
      _G.vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 128, stdout = '', stderr = 'fatal: not a git repository' }
          end,
        }
      end

      local is_bare = git.is_bare()

      assert.is_false(is_bare)
    end)
  end)
end)
