-- Agent: `:chat <message>` sends the current file plus your instruction to the
-- model and applies the result directly to the buffer. No sidebar.

local M = {}

local SYSTEM = table.concat({
  'You are an AI coding agent embedded in the openvim editor. You are given the',
  'full contents of the file the user is editing and an instruction. Apply the',
  'instruction by rewriting the file. Output ONLY the complete new file contents.',
  'No markdown code fences, no explanations, no commentary. Preserve the existing',
  'indentation style.',
}, ' ')

local function clean(text)
  if not text then return nil end
  text = text:gsub('^```[%w_-]*\n', ''):gsub('\n```%s*$', '')
  if text == '' then return nil end
  return text
end

function M.run(cfg, msg)
  if not msg or msg == '' then
    vim.notify('openvim: usage :chat <instruction>', vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable or vim.bo[buf].buftype ~= '' then
    vim.notify('openvim: open a normal file first (this buffer is not editable)',
      vim.log.levels.WARN)
    return
  end

  local code = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  local ft = vim.bo[buf].filetype

  local backend, err = require('openvim.ai.backends').get(cfg.provider)
  if not backend then
    vim.notify('openvim: ' .. err, vim.log.levels.ERROR)
    return
  end

  vim.notify('openvim: working…', vim.log.levels.INFO)
  backend.ask({
    system = SYSTEM,
    model = cfg.chat_models[cfg.provider],
    max_tokens = 4096,
    messages = { {
      role = 'user',
      content = string.format('File (%s):\n%s\n\nInstruction: %s', ft, code, msg),
    } },
  }, function(text, aerr)
    vim.schedule(function()
      if aerr then
        vim.notify('openvim chat: ' .. aerr, vim.log.levels.ERROR)
        return
      end
      local out = clean(text)
      if not out then
        vim.notify('openvim chat: empty response', vim.log.levels.WARN)
        return
      end
      if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modifiable then return end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(out, '\n', { plain = true }))
      vim.notify('openvim: done', vim.log.levels.INFO)
    end)
  end)
end

function M.setup(cfg)
  vim.api.nvim_create_user_command('Chat', function(o)
    M.run(cfg, o.args)
  end, { nargs = '+', desc = 'AI agent: edit the current file from an instruction' })

  -- Let the user type lowercase `:chat ...` and have it expand to `:Chat`.
  vim.cmd([[cnoreabbrev <expr> chat (getcmdtype() == ':' && getcmdline() ==# 'chat') ? 'Chat' : 'chat']])
end

return M
