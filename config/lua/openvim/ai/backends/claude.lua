-- Claude (Anthropic) completion backend.
-- Reads ANTHROPIC_API_KEY from the environment.

local M = {}

local SYSTEM = table.concat({
  'You are a code autocomplete engine embedded in a text editor.',
  'You receive the code before the cursor inside <prefix> and the code after',
  'the cursor inside <suffix>. Output ONLY the raw text that should be inserted',
  'at the cursor to continue the code naturally.',
  'Rules: no explanations, no markdown code fences, do not repeat the prefix or',
  'suffix, keep it short (usually finish the current line or a small block).',
  'If no useful completion exists, output nothing at all.',
}, ' ')

-- ctx: { prefix, suffix, filetype, model, max_tokens }
-- cb(text|nil, err|nil) -- called off the main loop; caller schedules.
function M.complete(ctx, cb)
  local api_key = vim.env.ANTHROPIC_API_KEY
  if not api_key or api_key == '' then
    cb(nil, 'ANTHROPIC_API_KEY not set')
    return
  end

  local user = string.format(
    'Language: %s\n<prefix>%s</prefix>\n<suffix>%s</suffix>',
    ctx.filetype or 'text', ctx.prefix or '', ctx.suffix or ''
  )

  local body = vim.json.encode({
    model = ctx.model,
    max_tokens = ctx.max_tokens or 256,
    system = SYSTEM,
    messages = { { role = 'user', content = user } },
  })

  return vim.system({
    'curl', '-sS', 'https://api.anthropic.com/v1/messages',
    '-H', 'content-type: application/json',
    '-H', 'x-api-key: ' .. api_key,
    '-H', 'anthropic-version: 2023-06-01',
    '--data-binary', '@-',
  }, { stdin = body, text = true }, function(res)
    if res.code ~= 0 then
      cb(nil, 'curl failed: ' .. (res.stderr or ('exit ' .. res.code)))
      return
    end
    local ok, decoded = pcall(vim.json.decode, res.stdout or '')
    if not ok or type(decoded) ~= 'table' then
      cb(nil, 'bad JSON from API')
      return
    end
    if decoded.error then
      cb(nil, decoded.error.message or 'API error')
      return
    end
    local text = decoded.content
      and decoded.content[1]
      and decoded.content[1].text
    cb(text, nil)
  end)
end

-- Instruction-following chat used by inline edit and the agent sidebar.
-- opts: { system, messages = {{role,content}...}, model, max_tokens }
function M.ask(opts, cb)
  local api_key = vim.env.ANTHROPIC_API_KEY
  if not api_key or api_key == '' then
    cb(nil, 'ANTHROPIC_API_KEY not set')
    return
  end

  local body = vim.json.encode({
    model = opts.model,
    max_tokens = opts.max_tokens or 1024,
    system = opts.system,
    messages = opts.messages,
  })

  return vim.system({
    'curl', '-sS', 'https://api.anthropic.com/v1/messages',
    '-H', 'content-type: application/json',
    '-H', 'x-api-key: ' .. api_key,
    '-H', 'anthropic-version: 2023-06-01',
    '--data-binary', '@-',
  }, { stdin = body, text = true }, function(res)
    if res.code ~= 0 then
      cb(nil, 'curl failed: ' .. (res.stderr or ('exit ' .. res.code)))
      return
    end
    local ok, decoded = pcall(vim.json.decode, res.stdout or '')
    if not ok or type(decoded) ~= 'table' then
      cb(nil, 'bad JSON from API')
      return
    end
    if decoded.error then
      cb(nil, decoded.error.message or 'API error')
      return
    end
    cb(decoded.content and decoded.content[1] and decoded.content[1].text, nil)
  end)
end

return M
