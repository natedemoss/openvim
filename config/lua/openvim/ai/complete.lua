-- Inline autocomplete: Copilot-style ghost text driven by a pluggable backend.
-- Debounces typing, requests a completion, renders it as virtual text, and
-- accepts it with <Tab>.

local M = {}

local ns = vim.api.nvim_create_namespace('openvim_complete')
-- Smaller context = faster prompt processing on CPU. Tunable via cfg.
local PREFIX_LINES = 60 -- context window above the cursor
local SUFFIX_LINES = 15 -- context window below the cursor

local state = {
  cfg = nil,
  enabled = true,
  timer = nil,
  token = 0,          -- bumped per request to drop stale responses
  job = nil,          -- in-flight backend process handle (for cancellation)
  suggestion = nil,   -- accepted-as-is text currently shown
  extmark = nil,
  bufnr = nil,
}

-- Abort any in-flight request so overlapping calls don't thrash the CPU.
local function cancel_job()
  if state.job then
    pcall(function() state.job:kill('sigterm') end)
    state.job = nil
  end
end

-- Strip accidental markdown fences a model might wrap around the code.
local function clean(text)
  if not text or text == '' then return nil end
  text = text:gsub('^```[%w_-]*\n', ''):gsub('\n```%s*$', '')
  if text == '' then return nil end
  return text
end

function M.clear()
  cancel_job()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
  end
  state.suggestion = nil
  state.extmark = nil
  state.bufnr = nil
end

function M.visible()
  return state.suggestion ~= nil
end

local function render(text)
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0)) -- row 1-based, col 0-based
  row = row - 1
  local lines = vim.split(text, '\n', { plain = true })

  local virt_lines = {}
  for i = 2, #lines do
    virt_lines[#virt_lines + 1] = { { lines[i], 'Comment' } }
  end

  state.extmark = vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
    virt_text = { { lines[1], 'Comment' } },
    virt_text_pos = 'inline',
    virt_lines = #virt_lines > 0 and virt_lines or nil,
  })
  state.suggestion = text
  state.bufnr = buf
end

local function build_context()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local last = vim.api.nvim_buf_line_count(buf) - 1

  local pstart = math.max(0, row - (state.cfg.prefix_lines or PREFIX_LINES))
  local before = vim.api.nvim_buf_get_lines(buf, pstart, row, false)
  local cur = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
  before[#before + 1] = cur:sub(1, col)

  local after = { cur:sub(col + 1) }
  local send = math.min(last, row + (state.cfg.suffix_lines or SUFFIX_LINES))
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, row + 1, send + 1, false)) do
    after[#after + 1] = l
  end

  return {
    prefix = table.concat(before, '\n'),
    suffix = table.concat(after, '\n'),
    filetype = vim.bo[buf].filetype,
    model = state.cfg.models[state.cfg.provider],
    max_tokens = state.cfg.max_tokens,
  }
end

local function request()
  if not state.enabled then return end
  if vim.fn.mode() ~= 'i' then return end

  local backends = require('openvim.ai.backends')
  local backend, err = backends.get(state.cfg.provider)
  if not backend then
    vim.notify('openvim: ' .. err, vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  state.token = state.token + 1
  local my_token = state.token

  cancel_job()
  state.job = backend.complete(build_context(), function(text, cerr)
    vim.schedule(function()
      -- Drop if a newer request started, or the buffer/cursor moved.
      if my_token ~= state.token then return end
      if cerr then
        vim.notify('openvim ai: ' .. cerr, vim.log.levels.WARN)
        return
      end
      if vim.fn.mode() ~= 'i' then return end
      if not vim.api.nvim_buf_is_valid(buf) then return end
      if vim.api.nvim_buf_get_changedtick(buf) ~= tick then return end
      local now = vim.api.nvim_win_get_cursor(0)
      if now[1] ~= cursor[1] or now[2] ~= cursor[2] then return end

      local s = clean(text)
      if not s then return end
      M.clear()
      render(s)
    end)
  end)
end

local function schedule_request()
  M.clear()
  if state.timer then
    state.timer:stop()
  else
    state.timer = vim.uv.new_timer()
  end
  state.timer:start(state.cfg.debounce_ms, 0, function()
    vim.schedule(request)
  end)
end

-- Accept the current suggestion. Returns true if something was accepted.
function M.accept()
  if not state.suggestion then return false end
  if not vim.bo.modifiable then return false end
  local text = state.suggestion
  M.clear()

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local lines = vim.split(text, '\n', { plain = true })
  vim.api.nvim_buf_set_text(0, row, col, row, col, lines)

  if #lines == 1 then
    vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
  else
    vim.api.nvim_win_set_cursor(0, { row + #lines, #lines[#lines] })
  end
  return true
end

function M.enable() state.enabled = true end
function M.disable()
  state.enabled = false
  M.clear()
end
function M.toggle()
  if state.enabled then M.disable() else M.enable() end
  return state.enabled
end

function M.setup(cfg)
  state.cfg = cfg

  local grp = vim.api.nvim_create_augroup('openvim_complete', { clear = true })
  vim.api.nvim_create_autocmd('TextChangedI', {
    group = grp,
    callback = schedule_request,
  })
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave' }, {
    group = grp,
    callback = function()
      if state.timer then state.timer:stop() end
      M.clear()
    end,
  })

  -- <Tab> accepts a suggestion, otherwise behaves like a normal Tab.
  -- Not an expr mapping: expr mappings forbid changing buffer text (E565),
  -- and accept() inserts via nvim_buf_set_text.
  local tab_key = vim.api.nvim_replace_termcodes('<Tab>', true, false, true)
  vim.keymap.set('i', '<Tab>', function()
    if not M.accept() then
      vim.api.nvim_feedkeys(tab_key, 'n', false) -- 'n' = no remap, won't re-trigger this map
    end
  end, { desc = 'openvim: accept suggestion or insert tab' })

  -- <C-]> dismisses the current suggestion.
  vim.keymap.set('i', '<C-]>', function() M.clear() end,
    { desc = 'openvim: dismiss suggestion' })
end

return M
