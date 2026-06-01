-- OpenAI completion backend.
-- Reads OPENAI_API_KEY from the environment.

local M = {}

local SYSTEM = table.concat({
  'You are a code autocomplete engine. You receive code before the cursor in',
  '<prefix> and code after the cursor in <suffix>. Output ONLY the raw text to',
  'insert at the cursor. No explanations, no markdown fences, no repetition of',
  'the prefix or suffix. Keep it short. Output nothing if no completion fits.',
}, ' ')

function M.complete(ctx, cb)
  local api_key = vim.env.OPENAI_API_KEY
  if not api_key or api_key == '' then
    cb(nil, 'OPENAI_API_KEY not set')
    return
  end

  local user = string.format(
    'Language: %s\n<prefix>%s</prefix>\n<suffix>%s</suffix>',
    ctx.filetype or 'text', ctx.prefix or '', ctx.suffix or ''
  )

  local body = vim.json.encode({
    model = ctx.model,
    max_tokens = ctx.max_tokens or 256,
    messages = {
      { role = 'system', content = SYSTEM },
      { role = 'user', content = user },
    },
  })

  return vim.system({
    'curl', '-sS', 'https://api.openai.com/v1/chat/completions',
    '-H', 'content-type: application/json',
    '-H', 'authorization: Bearer ' .. api_key,
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
    local text = decoded.choices
      and decoded.choices[1]
      and decoded.choices[1].message
      and decoded.choices[1].message.content
    cb(text, nil)
  end)
end

-- Instruction-following chat used by inline edit and the agent sidebar.
-- opts: { system, messages = {{role,content}...}, model, max_tokens }
function M.ask(opts, cb)
  local api_key = vim.env.OPENAI_API_KEY
  if not api_key or api_key == '' then
    cb(nil, 'OPENAI_API_KEY not set')
    return
  end

  local messages = {}
  if opts.system then messages[1] = { role = 'system', content = opts.system } end
  for _, m in ipairs(opts.messages or {}) do messages[#messages + 1] = m end

  local body = vim.json.encode({
    model = opts.model,
    max_tokens = opts.max_tokens or 1024,
    messages = messages,
  })

  return vim.system({
    'curl', '-sS', 'https://api.openai.com/v1/chat/completions',
    '-H', 'content-type: application/json',
    '-H', 'authorization: Bearer ' .. api_key,
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
    cb(decoded.choices and decoded.choices[1] and decoded.choices[1].message
      and decoded.choices[1].message.content, nil)
  end)
end

return M
