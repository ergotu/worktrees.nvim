describe('actions.remove', function()
  local remove_action
  local input_mock
  local notification_mock
  local worktree_mock
  local shared_mock
  local config_mock
  local recents_mock
  local vim_mock
  local selected_worktree
  local confirmation_result
  local remove_result

  before_each(function()
    -- Reset state
    selected_worktree = { path = '/home/user/other-worktree', branch = 'feature/test' }
    confirmation_result = true
    remove_result = { success = true, stdout = {}, stderr = {} }

    vim_mock = {
      uv = {
        cwd = function()
          return '/home/user/current-worktree'
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
      select_worktree = function(opts, callback)
        callback(selected_worktree)
      end,
      get_confirmation = function(msg, opts)
        return confirmation_result
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

    -- Mock worktree module
    worktree_mock = {
      remove = function(path, opts)
        return remove_result
      end,
    }
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    -- Mock shared module
    shared_mock = {
      emit_event = function() end,
    }
    package.loaded['worktrees.actions.shared'] = shared_mock

    -- Mock config module
    config_mock = {
      values = {
        hooks = {
          before_remove = nil,
          after_remove = nil,
        },
      },
    }
    package.loaded['worktrees.config'] = config_mock

    -- Mock recents module
    recents_mock = {
      remove = function() end,
    }
    package.loaded['worktrees.lib.recents'] = recents_mock

    -- Reload module
    package.loaded['worktrees.actions.remove'] = nil
    remove_action = require('worktrees.actions.remove')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.actions.remove'] = nil
    package.loaded['worktrees.lib.input'] = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.lib.git.worktree'] = nil
    package.loaded['worktrees.actions.shared'] = nil
    package.loaded['worktrees.config'] = nil
    package.loaded['worktrees.lib.recents'] = nil
  end)

  describe('remove', function()
    it('successfully removes a worktree', function()
      local info_called = false
      notification_mock.info = function(msg)
        info_called = true
        assert.is_truthy(msg:match('/home/user/other%-worktree'))
      end

      remove_action.remove()
      assert.is_true(info_called)
    end)

    it('prompts for confirmation before removing', function()
      local confirm_called = false
      input_mock.get_confirmation = function(msg, opts)
        confirm_called = true
        assert.is_truthy(msg:match('/home/user/other%-worktree'))
        assert.are.equal(2, opts.default) -- Default to No
        return true
      end

      remove_action.remove()
      assert.is_true(confirm_called)
    end)

    it('cancels removal when confirmation is declined', function()
      confirmation_result = false
      local remove_called = false
      worktree_mock.remove = function()
        remove_called = true
        return remove_result
      end

      remove_action.remove()
      assert.is_false(remove_called)
    end)

    it('warns when trying to remove current worktree', function()
      selected_worktree = { path = '/home/user/current-worktree', branch = 'main' }
      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
        assert.is_truthy(msg:match('Cannot remove current worktree'))
      end

      remove_action.remove()
      assert.is_true(warn_called)
    end)

    it('handles nil selection', function()
      selected_worktree = nil
      local remove_called = false
      worktree_mock.remove = function()
        remove_called = true
        return remove_result
      end

      remove_action.remove()
      assert.is_false(remove_called)
    end)

    it('removes worktree from recents on success', function()
      local removed_path = nil
      recents_mock.remove = function(path)
        removed_path = path
      end

      remove_action.remove()
      assert.are.equal('/home/user/other-worktree', removed_path)
    end)

    it('emits Removed event on success', function()
      local emitted_event = nil
      local emitted_data = nil
      shared_mock.emit_event = function(event, data)
        emitted_event = event
        emitted_data = data
      end

      remove_action.remove()
      assert.are.equal('Removed', emitted_event)
      assert.are.equal('/home/user/other-worktree', emitted_data.path)
    end)

    it('calls before_remove hook when configured', function()
      local hook_called = false
      local hook_path = nil
      config_mock.values.hooks.before_remove = function(path)
        hook_called = true
        hook_path = path
      end

      remove_action.remove()
      assert.is_true(hook_called)
      assert.are.equal('/home/user/other-worktree', hook_path)
    end)

    it('calls after_remove hook on success', function()
      local hook_called = false
      local hook_path = nil
      config_mock.values.hooks.after_remove = function(path)
        hook_called = true
        hook_path = path
      end

      remove_action.remove()
      assert.is_true(hook_called)
      assert.are.equal('/home/user/other-worktree', hook_path)
    end)

    it('does not call after_remove hook on failure', function()
      remove_result = {
        success = false,
        stdout = {},
        stderr = { 'error message' },
      }

      local hook_called = false
      config_mock.values.hooks.after_remove = function()
        hook_called = true
      end

      -- User declines force removal
      local confirm_count = 0
      input_mock.get_confirmation = function()
        confirm_count = confirm_count + 1
        if confirm_count == 1 then
          return true -- Initial confirmation
        else
          return false -- Decline force removal
        end
      end

      remove_action.remove()
      assert.is_false(hook_called)
    end)

    it('shows error message on removal failure', function()
      remove_result = {
        success = false,
        stdout = {},
        stderr = { 'cannot remove worktree' },
      }

      local error_called = false
      notification_mock.error = function(msg)
        error_called = true
        assert.is_truthy(msg:match('cannot remove worktree'))
      end

      -- User declines force removal
      local confirm_count = 0
      input_mock.get_confirmation = function()
        confirm_count = confirm_count + 1
        if confirm_count == 1 then
          return true -- Initial confirmation
        else
          return false -- Decline force removal
        end
      end

      remove_action.remove()
      assert.is_true(error_called)
    end)

    it('prompts for force removal on failure', function()
      remove_result = {
        success = false,
        stdout = {},
        stderr = { 'worktree has changes' },
      }

      local force_prompt_called = false
      local confirm_count = 0
      input_mock.get_confirmation = function(msg, opts)
        confirm_count = confirm_count + 1
        if confirm_count == 1 then
          return true -- Initial confirmation
        else
          force_prompt_called = true
          assert.is_truthy(msg:match('force'))
          return false
        end
      end

      remove_action.remove()
      assert.is_true(force_prompt_called)
    end)

    it('retries with force when user confirms', function()
      local remove_calls = {}
      worktree_mock.remove = function(path, opts)
        table.insert(remove_calls, { path = path, force = opts.force })
        if #remove_calls == 1 then
          return { success = false, stdout = {}, stderr = { 'error' } }
        else
          return { success = true, stdout = {}, stderr = {} }
        end
      end

      -- User confirms both initial and force removal
      input_mock.get_confirmation = function()
        return true
      end

      remove_action.remove()

      assert.are.equal(2, #remove_calls)
      assert.is_false(remove_calls[1].force)
      assert.is_true(remove_calls[2].force)
    end)

    it('shows error when force removal also fails', function()
      worktree_mock.remove = function(path, opts)
        return {
          success = false,
          stdout = {},
          stderr = { 'force removal failed' },
        }
      end

      local error_messages = {}
      notification_mock.error = function(msg)
        table.insert(error_messages, msg)
      end

      -- User confirms both initial and force removal
      input_mock.get_confirmation = function()
        return true
      end

      remove_action.remove()

      assert.are.equal(2, #error_messages)
      assert.is_truthy(error_messages[2]:match('Force removal failed'))
    end)

    it('passes include_current false to select_worktree', function()
      local select_opts = nil
      input_mock.select_worktree = function(opts, callback)
        select_opts = opts
        callback(selected_worktree)
      end

      remove_action.remove()
      assert.is_false(select_opts.include_current)
    end)

    it('uses custom prompt for select_worktree', function()
      local select_opts = nil
      input_mock.select_worktree = function(opts, callback)
        select_opts = opts
        callback(selected_worktree)
      end

      remove_action.remove()
      assert.is_truthy(select_opts.prompt:match('Select worktree to remove'))
    end)
  end)
end)
