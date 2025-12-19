describe('actions.add', function()
  local add_action
  local input_mock
  local notification_mock
  local refs_mock
  local git_mock
  local worktree_mock
  local branch_mock
  local shared_mock
  local config_mock
  local recents_mock
  local path_mock
  local vim_mock
  local input_response
  local selected_ref
  local worktree_add_result
  local git_run_result
  local existing_branches

  before_each(function()
    -- Reset state
    input_response = 'feature/test'
    selected_ref = 'origin/main'
    existing_branches = {}
    worktree_add_result = { success = true, stdout = {}, stderr = {} }
    git_run_result = { success = true, stdout = {}, stderr = {} }

    vim_mock = {
      fn = {
        isdirectory = function()
          return 0
        end,
      },
      fs = {
        dirname = function(path)
          return path:match('(.+)/[^/]*$') or '.'
        end,
        basename = function(path)
          return path:match('[^/]+$')
        end,
      },
      uv = {
        cwd = function()
          return '/home/user/current'
        end,
      },
      tbl_contains = function(tbl, value)
        for _, v in ipairs(tbl) do
          if v == value then
            return true
          end
        end
        return false
      end,
    }

    _G.vim = vim_mock

    -- Mock input module
    input_mock = {
      get_user_input = function()
        return input_response
      end,
      get_confirmation = function()
        return true
      end,
      select_ref = function(opts, callback)
        callback(selected_ref)
      end,
    }
    package.loaded['worktrees.lib.input'] = input_mock

    -- Mock notification module
    notification_mock = {
      info = function() end,
      warn = function() end,
      error = function() end,
    }
    package.loaded['worktrees.lib.notification'] = notification_mock

    -- Mock refs module
    refs_mock = {
      list_branches = function()
        return existing_branches
      end,
    }
    package.loaded['worktrees.lib.git.refs'] = refs_mock

    -- Mock git module
    git_mock = {
      run = function()
        return git_run_result
      end,
    }
    package.loaded['worktrees.lib.git'] = git_mock

    -- Mock worktree module
    worktree_mock = {
      list = function()
        return {}
      end,
      add = function()
        return worktree_add_result
      end,
    }
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    -- Mock branch module
    branch_mock = {
      set_upstream = function()
        return { success = true, stdout = {}, stderr = {} }
      end,
    }
    package.loaded['worktrees.lib.git.branch'] = branch_mock

    -- Mock shared module
    shared_mock = {
      switch_to_worktree = function() end,
      emit_event = function() end,
    }
    package.loaded['worktrees.actions.shared'] = shared_mock

    -- Mock config module
    config_mock = {
      values = {
        aliases = {},
        templates = {},
        hooks = {
          before_create = nil,
          after_create = nil,
        },
        auto_track_upstream = false,
      },
    }
    package.loaded['worktrees.config'] = config_mock

    -- Mock recents module
    recents_mock = {
      add = function() end,
    }
    package.loaded['worktrees.lib.recents'] = recents_mock

    -- Mock path module
    path_mock = {
      calculate_path = function(branch_name)
        return '/home/user/worktrees/' .. branch_name
      end,
    }
    package.loaded['worktrees.lib.path'] = path_mock

    -- Reload module
    package.loaded['worktrees.actions.add'] = nil
    add_action = require('worktrees.actions.add')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.actions.add'] = nil
    package.loaded['worktrees.lib.input'] = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.lib.git.refs'] = nil
    package.loaded['worktrees.lib.git'] = nil
    package.loaded['worktrees.lib.git.worktree'] = nil
    package.loaded['worktrees.lib.git.branch'] = nil
    package.loaded['worktrees.actions.shared'] = nil
    package.loaded['worktrees.config'] = nil
    package.loaded['worktrees.lib.recents'] = nil
    package.loaded['worktrees.lib.path'] = nil
  end)

  describe('branch name validation', function()
    it('rejects empty branch names', function()
      input_response = ''
      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names with only whitespace', function()
      input_response = '   '
      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names with double dots', function()
      input_response = 'feature..test'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names with forbidden characters', function()
      local invalid_names = {
        'feature~test',
        'feature^test',
        'feature:test',
        'feature test',
        'feature?test',
        'feature*test',
        'feature[test',
        'feature\\test',
        'feature@{test',
      }

      for _, name in ipairs(invalid_names) do
        input_response = name
        local warn_called = false
        notification_mock.warn = function()
          warn_called = true
        end

        add_action.add()
        assert.is_true(warn_called, 'Should reject: ' .. name)
      end
    end)

    it('rejects branch names starting with slash', function()
      input_response = '/feature'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names ending with slash', function()
      input_response = 'feature/'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names with double slashes', function()
      input_response = 'feature//test'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('rejects branch names ending with @', function()
      input_response = 'feature@'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_true(warn_called)
    end)

    it('accepts valid branch names', function()
      input_response = 'feature/valid-branch_123'
      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      add_action.add()
      assert.is_false(warn_called)
    end)
  end)

  describe('alias expansion', function()
    it('expands configured aliases', function()
      input_response = 'feat'
      config_mock.values.aliases = { feat = 'feature/' }

      local created_branch = nil
      git_mock.run = function(opts)
        for i, arg in ipairs(opts.args) do
          if arg == '-b' and opts.args[i + 1] then
            created_branch = opts.args[i + 1]
            break
          end
        end
        return git_run_result
      end

      add_action.add()
      assert.are.equal('feature/', created_branch)
    end)

    it('does not modify non-aliased names', function()
      input_response = 'feature/test'
      config_mock.values.aliases = { feat = 'feature/' }

      local created_branch = nil
      git_mock.run = function(opts)
        for i, arg in ipairs(opts.args) do
          if arg == '-b' and opts.args[i + 1] then
            created_branch = opts.args[i + 1]
            break
          end
        end
        return git_run_result
      end

      add_action.add()
      assert.are.equal('feature/test', created_branch)
    end)
  end)

  describe('template matching', function()
    it('applies matching template', function()
      input_response = 'feature/test'
      config_mock.values.templates = {
        ['^feature/'] = {
          base_ref = 'origin/develop',
          path_prefix = 'feat-',
        },
      }

      local created_path = nil
      git_mock.run = function(opts)
        created_path = opts.args[#opts.args - 1]
        return git_run_result
      end

      add_action.add()
      assert.is_truthy(created_path:match('feat%-'))
    end)

    it('uses template base_ref automatically', function()
      input_response = 'feature/test'
      config_mock.values.templates = {
        ['^feature/'] = {
          base_ref = 'origin/develop',
        },
      }

      local used_base = nil
      git_mock.run = function(opts)
        used_base = opts.args[#opts.args]
        return git_run_result
      end

      add_action.add()
      assert.are.equal('origin/develop', used_base)
    end)

    it('prompts for ref when no template base_ref', function()
      input_response = 'feature/test'
      local select_called = false
      input_mock.select_ref = function(opts, callback)
        select_called = true
        callback('origin/main')
      end

      add_action.add()
      assert.is_true(select_called)
    end)
  end)

  describe('existing branch handling', function()
    it('creates from existing branch without prompting', function()
      input_response = 'existing-branch'
      existing_branches = { 'existing-branch' }

      local select_called = false
      input_mock.select_ref = function()
        select_called = true
      end

      add_action.add()
      assert.is_false(select_called)
    end)

    it('uses worktree.add for existing branches', function()
      input_response = 'existing-branch'
      existing_branches = { 'existing-branch' }

      local add_called = false
      worktree_mock.add = function(path, opts)
        add_called = true
        assert.are.equal('existing-branch', opts.commitish)
        return worktree_add_result
      end

      add_action.add()
      assert.is_true(add_called)
    end)
  end)

  describe('new branch creation', function()
    it('creates new branch with selected ref', function()
      input_response = 'new-branch'
      selected_ref = 'origin/main'

      local git_args = nil
      git_mock.run = function(opts)
        git_args = opts.args
        return git_run_result
      end

      add_action.add()
      assert.is_truthy(vim.tbl_contains(git_args, 'new-branch'))
      assert.is_truthy(vim.tbl_contains(git_args, 'origin/main'))
    end)

    it('cancels creation when no ref selected', function()
      input_response = 'new-branch'
      selected_ref = nil

      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
        assert.is_truthy(msg:match('canceled'))
      end

      add_action.add()
      assert.is_true(warn_called)
    end)
  end)

  describe('path handling', function()
    it('switches to existing worktree when path already exists', function()
      input_response = 'test-branch'
      vim_mock.fn.isdirectory = function()
        return 1
      end
      worktree_mock.list = function()
        return { { path = '/home/user/worktrees/test-branch' } }
      end

      local switched_to = nil
      shared_mock.switch_to_worktree = function(path)
        switched_to = path
      end

      add_action.add()
      assert.are.equal('/home/user/worktrees/test-branch', switched_to)
    end)

    it('prompts for overwrite when path exists but not a worktree', function()
      input_response = 'test-branch'
      vim_mock.fn.isdirectory = function()
        return 1
      end
      worktree_mock.list = function()
        return {}
      end

      local confirm_called = false
      input_mock.get_confirmation = function(msg)
        confirm_called = true
        assert.is_truthy(msg:match('overwrite'))
        return true
      end

      add_action.add()
      assert.is_true(confirm_called)
    end)

    it('cancels when user declines overwrite', function()
      input_response = 'test-branch'
      vim_mock.fn.isdirectory = function()
        return 1
      end
      worktree_mock.list = function()
        return {}
      end
      input_mock.get_confirmation = function()
        return false
      end

      local git_called = false
      git_mock.run = function()
        git_called = true
        return git_run_result
      end

      add_action.add()
      assert.is_false(git_called)
    end)
  end)

  describe('hooks', function()
    it('calls before_create hook', function()
      input_response = 'test-branch'
      local hook_called = false
      config_mock.values.hooks.before_create = function(branch, path)
        hook_called = true
        assert.are.equal('test-branch', branch)
      end

      add_action.add()
      assert.is_true(hook_called)
    end)

    it('calls after_create hook on success', function()
      input_response = 'test-branch'
      local hook_called = false
      config_mock.values.hooks.after_create = function(branch, path)
        hook_called = true
        assert.are.equal('test-branch', branch)
      end

      add_action.add()
      assert.is_true(hook_called)
    end)

    it('does not call after_create hook on failure', function()
      input_response = 'test-branch'
      git_run_result = { success = false, stdout = {}, stderr = { 'error' } }

      local hook_called = false
      config_mock.values.hooks.after_create = function()
        hook_called = true
      end

      add_action.add()
      assert.is_false(hook_called)
    end)

    it('calls template before_create hook', function()
      input_response = 'feature/test'
      local hook_called = false
      config_mock.values.templates = {
        ['^feature/'] = {
          base_ref = 'main',
          hooks = {
            before_create = function(branch, path)
              hook_called = true
            end,
          },
        },
      }

      add_action.add()
      assert.is_true(hook_called)
    end)

    it('calls template after_create hook on success', function()
      input_response = 'feature/test'
      local hook_called = false
      config_mock.values.templates = {
        ['^feature/'] = {
          base_ref = 'main',
          hooks = {
            after_create = function(branch, path)
              hook_called = true
            end,
          },
        },
      }

      add_action.add()
      assert.is_true(hook_called)
    end)
  end)

  describe('upstream tracking', function()
    it('sets upstream when base is remote and auto_track enabled', function()
      input_response = 'test-branch'
      selected_ref = 'origin/main'
      config_mock.values.auto_track_upstream = true

      local upstream_set = false
      branch_mock.set_upstream = function()
        upstream_set = true
        return { success = true, stdout = {}, stderr = {} }
      end

      add_action.add()
      assert.is_true(upstream_set)
    end)

    it('does not set upstream for local branches', function()
      input_response = 'test-branch'
      selected_ref = 'main'
      config_mock.values.auto_track_upstream = true

      local upstream_set = false
      branch_mock.set_upstream = function()
        upstream_set = true
        return { success = true, stdout = {}, stderr = {} }
      end

      add_action.add()
      assert.is_false(upstream_set)
    end)

    it('sets upstream when template auto_track is true', function()
      input_response = 'feature/test'
      config_mock.values.templates = {
        ['^feature/'] = {
          base_ref = 'origin/develop',
          auto_track = true,
        },
      }

      local upstream_set = false
      branch_mock.set_upstream = function()
        upstream_set = true
        return { success = true, stdout = {}, stderr = {} }
      end

      add_action.add()
      assert.is_true(upstream_set)
    end)
  end)

  describe('recents tracking', function()
    it('adds worktree to recents on success', function()
      input_response = 'test-branch'
      local added = false
      recents_mock.add = function(path, branch)
        added = true
        assert.is_truthy(path:match('test%-branch'))
        assert.are.equal('test-branch', branch)
      end

      add_action.add()
      assert.is_true(added)
    end)

    it('does not add to recents on failure', function()
      input_response = 'test-branch'
      git_run_result = { success = false, stdout = {}, stderr = { 'error' } }

      local added = false
      recents_mock.add = function()
        added = true
      end

      add_action.add()
      assert.is_false(added)
    end)
  end)

  describe('event emission', function()
    it('emits Created event on success', function()
      input_response = 'test-branch'
      local event_name = nil
      local event_data = nil
      shared_mock.emit_event = function(name, data)
        event_name = name
        event_data = data
      end

      add_action.add()
      assert.are.equal('Created', event_name)
      assert.are.equal('test-branch', event_data.branch)
      assert.is_not_nil(event_data.path)
      assert.is_not_nil(event_data.previous_path)
    end)

    it('includes upstream in event when tracking is enabled', function()
      input_response = 'test-branch'
      selected_ref = 'origin/main'
      config_mock.values.auto_track_upstream = true

      local event_data = nil
      shared_mock.emit_event = function(name, data)
        event_data = data
      end

      add_action.add()
      assert.are.equal('origin/main', event_data.upstream)
    end)

    it('does not emit event on failure', function()
      input_response = 'test-branch'
      git_run_result = { success = false, stdout = {}, stderr = { 'error' } }

      local event_emitted = false
      shared_mock.emit_event = function()
        event_emitted = true
      end

      add_action.add()
      assert.is_false(event_emitted)
    end)
  end)

  describe('error handling', function()
    it('shows error message on creation failure', function()
      input_response = 'test-branch'
      git_run_result = {
        success = false,
        stdout = {},
        stderr = { 'fatal: invalid reference' },
      }

      local error_called = false
      notification_mock.error = function(msg)
        error_called = true
        assert.is_truthy(msg:match('fatal: invalid reference'))
      end

      add_action.add()
      assert.is_true(error_called)
    end)

    it('warns when upstream tracking fails', function()
      input_response = 'test-branch'
      selected_ref = 'origin/main'
      config_mock.values.auto_track_upstream = true

      branch_mock.set_upstream = function()
        return {
          success = false,
          stdout = {},
          stderr = { 'no such remote' },
        }
      end

      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
        assert.is_truthy(msg:match('upstream'))
      end

      add_action.add()
      assert.is_true(warn_called)
    end)
  end)
end)
