describe('lib.input', function()
  local input
  local notification_mock
  local refs_mock
  local worktree_mock
  local vim_mock
  local input_response
  local confirm_response
  local select_response

  before_each(function()
    -- Track function calls
    input_response = nil
    confirm_response = 1
    select_response = nil

    vim_mock = {
      fn = {
        input = function(opts)
          return input_response or opts.cancelreturn
        end,
        confirm = function(msg, values, default)
          return confirm_response
        end,
        getcwd = function()
          return '/home/user/current'
        end,
      },
      api = {
        nvim_replace_termcodes = function(str, from_part, do_lt, special)
          return str
        end,
        nvim_feedkeys = function(keys, mode, escape_csi) end,
      },
      ui = {
        select = function(items, opts, callback)
          if select_response ~= nil then
            callback(items[select_response], select_response)
          else
            callback(nil, nil)
          end
        end,
      },
      cmd = {
        redraw = function() end,
      },
      tbl_deep_extend = function(behavior, ...)
        local result = {}
        for i = 1, select('#', ...) do
          local tbl = select(i, ...)
          if tbl then
            for k, v in pairs(tbl) do
              if type(v) == 'table' and type(result[k]) == 'table' then
                result[k] = vim_mock.tbl_deep_extend(behavior, result[k], v)
              else
                result[k] = v
              end
            end
          end
        end
        return result
      end,
      tbl_extend = function(behavior, ...)
        local result = {}
        for i = 1, select('#', ...) do
          local tbl = select(i, ...)
          if tbl then
            for k, v in pairs(tbl) do
              result[k] = v
            end
          end
        end
        return result
      end,
      tbl_map = function(fn, tbl)
        local result = {}
        for i, v in ipairs(tbl) do
          result[i] = fn(v)
        end
        return result
      end,
      tbl_isempty = function(tbl)
        return next(tbl) == nil
      end,
      tbl_filter = function(fn, tbl)
        local result = {}
        for _, v in ipairs(tbl) do
          if fn(v) then
            table.insert(result, v)
          end
        end
        return result
      end,
    }

    _G.vim = vim_mock

    -- Mock notification module
    notification_mock = {
      warn = function() end,
    }
    package.loaded['worktrees.lib.notification'] = notification_mock

    -- Mock refs module
    refs_mock = {
      list_local_branches = function()
        return { 'main', 'develop' }
      end,
      list_remote_branches = function()
        return { 'origin/main', 'origin/feature' }
      end,
      list_heads = function()
        return { 'HEAD' }
      end,
      list_tags = function()
        return { 'v1.0.0', 'v2.0.0' }
      end,
    }
    package.loaded['worktrees.lib.git.refs'] = refs_mock

    -- Mock worktree module
    worktree_mock = {
      list = function()
        return {
          { path = '/home/user/worktree1', branch = 'feature/test' },
          { path = '/home/user/current', branch = 'main' },
          { path = '/home/user/worktree2', branch = nil },
        }
      end,
    }
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    -- Reload module
    package.loaded['worktrees.lib.input'] = nil
    input = require('worktrees.lib.input')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.lib.input'] = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.lib.git.refs'] = nil
    package.loaded['worktrees.lib.git.worktree'] = nil
  end)

  describe('get_user_input', function()
    it('returns user input when provided', function()
      input_response = 'test-input'
      local result = input.get_user_input('Enter name')
      assert.are.equal('test-input', result)
    end)

    it('returns nil when input is empty', function()
      input_response = ''
      local result = input.get_user_input('Enter name')
      assert.is_nil(result)
    end)

    it('returns nil when input matches cancel value', function()
      input_response = ''
      local result = input.get_user_input('Enter name', { cancel = '' })
      assert.is_nil(result)
    end)

    it('strips spaces when strip_spaces is true', function()
      input_response = 'test input with spaces'
      local result = input.get_user_input('Enter name', { strip_spaces = true })
      assert.are.equal('test-input-with-spaces', result)
    end)

    it('does not strip spaces by default', function()
      input_response = 'test input'
      local result = input.get_user_input('Enter name')
      assert.are.equal('test input', result)
    end)

    it('uses default separator when not provided', function()
      input_response = 'test'
      local called_with = nil
      vim_mock.fn.input = function(opts)
        called_with = opts.prompt
        return input_response
      end

      input.get_user_input('Enter name')
      assert.is_truthy(called_with:match('Enter name: '))
    end)

    it('uses custom separator when provided', function()
      input_response = 'test'
      local called_with = nil
      vim_mock.fn.input = function(opts)
        called_with = opts.prompt
        return input_response
      end

      input.get_user_input('Enter name', { separator = ' > ' })
      assert.is_truthy(called_with:match('Enter name > '))
    end)

    it('passes default value to vim.fn.input', function()
      input_response = 'test'
      local called_with = nil
      vim_mock.fn.input = function(opts)
        called_with = opts.default
        return input_response
      end

      input.get_user_input('Enter name', { default = 'default-value' })
      assert.are.equal('default-value', called_with)
    end)

    it('passes completion type to vim.fn.input', function()
      input_response = 'test'
      local called_with = nil
      vim_mock.fn.input = function(opts)
        called_with = opts.completion
        return input_response
      end

      input.get_user_input('Enter name', { completion = 'file' })
      assert.are.equal('file', called_with)
    end)
  end)

  describe('get_confirmation', function()
    it('returns true when user selects yes (default)', function()
      confirm_response = 1
      local result = input.get_confirmation('Proceed?')
      assert.is_true(result)
    end)

    it('returns false when user selects no', function()
      confirm_response = 2
      local result = input.get_confirmation('Proceed?')
      assert.is_false(result)
    end)

    it('uses custom default option', function()
      confirm_response = 2
      local called_with_default = nil
      vim_mock.fn.confirm = function(msg, values, default)
        called_with_default = default
        return confirm_response
      end

      input.get_confirmation('Proceed?', { default = 2 })
      assert.are.equal(2, called_with_default)
    end)

    it('uses custom ok_value', function()
      confirm_response = 2
      local result = input.get_confirmation('Proceed?', { ok_value = 2 })
      assert.is_true(result)
    end)

    it('passes custom values to confirm', function()
      confirm_response = 1
      local called_with_values = nil
      vim_mock.fn.confirm = function(msg, values, default)
        called_with_values = values
        return confirm_response
      end

      input.get_confirmation('Proceed?', { values = { '&Continue', '&Cancel' } })
      assert.are.equal('&Continue\n&Cancel', called_with_values)
    end)
  end)

  describe('select', function()
    it('calls callback with selected item', function()
      select_response = 2
      local selected = nil

      input.select({
        prompt = 'Select item:',
        fetcher = function()
          return { 'item1', 'item2', 'item3' }
        end,
        formatter = function(item)
          return item
        end,
      }, function(result)
        selected = result
      end)

      assert.are.equal('item2', selected)
    end)

    it('calls callback with nil when selection is cancelled', function()
      select_response = nil
      local selected = 'not-nil'

      input.select({
        prompt = 'Select item:',
        fetcher = function()
          return { 'item1', 'item2' }
        end,
        formatter = function(item)
          return item
        end,
      }, function(result)
        selected = result
      end)

      assert.is_nil(selected)
    end)

    it('shows warning when no items available', function()
      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
      end

      input.select({
        prompt = 'Select item:',
        fetcher = function()
          return {}
        end,
        formatter = function(item)
          return item
        end,
        no_items_msg = 'No items',
      }, function() end)

      assert.is_true(warn_called)
    end)

    it('formats items using provided formatter', function()
      select_response = 1
      local formatted_items = nil
      vim_mock.ui.select = function(items, opts, callback)
        formatted_items = items
        callback(items[1], 1)
      end

      input.select({
        prompt = 'Select item:',
        fetcher = function()
          return { { name = 'item1' }, { name = 'item2' } }
        end,
        formatter = function(item)
          return 'formatted-' .. item.name
        end,
      }, function() end)

      assert.are.equal('formatted-item1', formatted_items[1])
      assert.are.equal('formatted-item2', formatted_items[2])
    end)
  end)

  describe('select_ref', function()
    it('collects all reference types', function()
      select_response = 1
      local items_count = 0
      vim_mock.ui.select = function(items, opts, callback)
        items_count = #items
        callback(items[1], 1)
      end

      input.select_ref({}, function() end)

      -- 2 local + 2 remote + 1 head + 2 tags = 7
      assert.are.equal(7, items_count)
    end)

    it('excludes remotes when include_remotes is false', function()
      select_response = 1
      local items_count = 0
      vim_mock.ui.select = function(items, opts, callback)
        items_count = #items
        callback(items[1], 1)
      end

      input.select_ref({ include_remotes = false }, function() end)

      -- 2 local + 1 head + 2 tags = 5
      assert.are.equal(5, items_count)
    end)

    it('excludes heads when include_heads is false', function()
      select_response = 1
      local items_count = 0
      vim_mock.ui.select = function(items, opts, callback)
        items_count = #items
        callback(items[1], 1)
      end

      input.select_ref({ include_heads = false }, function() end)

      -- 2 local + 2 remote + 2 tags = 6
      assert.are.equal(6, items_count)
    end)

    it('returns name of selected reference', function()
      select_response = 1
      local selected = nil

      input.select_ref({}, function(result)
        selected = result
      end)

      -- First item should be a local branch
      assert.are.equal('main', selected)
    end)

    it('returns nil when selection is cancelled', function()
      select_response = nil
      local selected = 'not-nil'

      input.select_ref({}, function(result)
        selected = result
      end)

      assert.is_nil(selected)
    end)
  end)

  describe('select_worktree', function()
    it('lists all worktrees by default', function()
      select_response = 1
      local items_count = 0
      vim_mock.ui.select = function(items, opts, callback)
        items_count = #items
        callback(items[1], 1)
      end

      input.select_worktree({}, function() end)

      assert.are.equal(3, items_count)
    end)

    it('excludes current worktree when include_current is false', function()
      select_response = 1
      local items = nil
      vim_mock.ui.select = function(list, opts, callback)
        items = list
        callback(list[1], 1)
      end

      input.select_worktree({ include_current = false }, function() end)

      assert.are.equal(2, #items)
    end)

    it('returns selected worktree object', function()
      select_response = 1
      local selected = nil

      input.select_worktree({}, function(result)
        selected = result
      end)

      assert.are.equal('/home/user/worktree1', selected.path)
      assert.are.equal('feature/test', selected.branch)
    end)

    it('returns nil when selection is cancelled', function()
      select_response = nil
      local selected = 'not-nil'

      input.select_worktree({}, function(result)
        selected = result
      end)

      assert.is_nil(selected)
    end)

    it('handles worktree.list returning nil', function()
      worktree_mock.list = function()
        return nil
      end

      local warn_called = false
      notification_mock.warn = function()
        warn_called = true
      end

      input.select_worktree({}, function() end)

      assert.is_true(warn_called)
    end)

    it('formats worktrees with branch names', function()
      select_response = 1
      local formatted = nil
      vim_mock.ui.select = function(items, opts, callback)
        formatted = items[1]
        callback(items[1], 1)
      end

      input.select_worktree({}, function() end)

      assert.is_truthy(formatted:match('worktree1'))
      assert.is_truthy(formatted:match('%(test%)'))
    end)

    it('formats detached worktrees', function()
      select_response = 3
      local formatted = nil
      vim_mock.ui.select = function(items, opts, callback)
        formatted = items[3]
        callback(items[3], 3)
      end

      input.select_worktree({}, function() end)

      assert.is_truthy(formatted:match('%(detached%)'))
    end)
  end)
end)
