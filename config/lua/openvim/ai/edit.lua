-- Inline edit: select code (or a line range), describe a change, and the AI
-- rewrites it in place. Bound to :OpenvimEdit and <leader>ae in visual mode.

local M = {}

local SYSTEM = table.concat({
  'You are a code editor embedded in Neovim. You receive a block of code and an',
  'instruction. Rewrite the code to satisfy the instruction and output ONLY the',
  'replacement code. No explanations, no markdown code fences, no commentary.',
  'Preserve the original indentation style.',
}, ' ')

local function clean(text)
  if not text then return nil end
  text = text:gsub('^```[%w_-]*\n', ''):gsub('\n```%s*$', '')
  return text
end

-- line1/line2 are 1-based inclusive (from a command range). instruction is a
-- string; if nil, the user is prompted.
function M.run(cfg, line1, line2, instruction)
  local function go(instr)
    if not instr or instr == '' then return end
    local buf = vim.api.nvim_get_current_buf()
    if not vim.bo[buf].modifiable or vim.bo[buf].buftype ~= '' then
      vim.notify('openvim: this buffer is not editable', vim.log.levels.WARN)
      return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
    local code = table.concat(lines, '\n')

    local backend, err = require('openvim.ai.backends').get(cfg.provider)
    if not backend then
      vim.notify('openvim: ' .. err, vim.log.levels.ERROR)
      return
    end

    vim.notify('openvim: editing…', vim.log.levels.INFO)
    backend.ask({
      system = SYSTEM,
      model = cfg.chat_models[cfg.provider],
      max_tokens = 2048,
      messages = { {
        role = 'user',
        content = string.format('Instruction: %s\n\nCode:\n%s', instr, code),
      } },
    }, function(text, aerr)
      vim.schedule(function()
        if aerr then
          vim.notify('openvim edit: ' .. aerr, vim.log.levels.ERROR)
          return
        end
        local out = clean(text)
        if not out then
          vim.notify('openvim edit: empty response', vim.log.levels.WARN)
          return
        end
        if not vim.api.nvim_buf_is_valid(buf) then return end
        vim.api.nvim_buf_set_lines(buf, line1 - 1, line2,
          false, vim.split(out, '\n', { plain = true }))
        vim.notify('openvim: done', vim.log.levels.INFO)
      end)
    end)
  end

  if instruction and instruction ~= '' then
    go(instruction)
  else
    vim.ui.input({ prompt = 'openvim edit: ' }, go)
  end
end

function M.setup(cfg)
  vim.api.nvim_create_user_command('OpenvimEdit', function(o)
    M.run(cfg, o.line1, o.line2, o.args ~= '' and o.args or nil)
  end, { range = true, nargs = '*', desc = 'AI edit the selected lines' })

  vim.keymap.set('v', '<leader>ae', ':OpenvimEdit<cr>',
    { desc = 'openvim: AI edit selection' })
end

return M
