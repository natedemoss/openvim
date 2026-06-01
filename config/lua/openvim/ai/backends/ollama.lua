-- Ollama local completion backend.
-- Talks to a local Ollama server (default http://localhost:11434).
-- Uses the native fill-in-the-middle `suffix` param, so a code model such as
-- qwen2.5-coder or codellama gives the best results.

local M = {}

function M.complete(ctx, cb)
  local host = vim.env.OLLAMA_HOST
  if host and not host:match('^https?://') then host = 'http://' .. host end
  host = host or 'http://localhost:11434'

  local body = vim.json.encode({
    model = ctx.model,
    prompt = ctx.prefix or '',
    suffix = ctx.suffix or '',
    stream = false,
    keep_alive = '30m', -- keep the model resident so it never reloads
    options = {
      num_predict = ctx.max_tokens or 64,
      temperature = 0.1,
      -- Stop at a blank line: keeps completions tight and fast on CPU.
      stop = { '\n\n' },
    },
  })

  return vim.system({
    'curl', '-sS', host .. '/api/generate',
    '-H', 'content-type: application/json',
    '--data-binary', '@-',
  }, { stdin = body, text = true }, function(res)
    if res.code ~= 0 then
      cb(nil, 'curl failed: ' .. (res.stderr or ('exit ' .. res.code)))
      return
    end
    local ok, decoded = pcall(vim.json.decode, res.stdout or '')
    if not ok or type(decoded) ~= 'table' then
      cb(nil, 'bad JSON from Ollama (is it running?)')
      return
    end
    if decoded.error then
      cb(nil, tostring(decoded.error))
      return
    end
    cb(decoded.response, nil)
  end)
end

-- Instruction-following chat used by inline edit and the agent sidebar.
-- Uses /api/chat with an instruct model. opts: { system, messages, model, max_tokens }
function M.ask(opts, cb)
  local host = vim.env.OLLAMA_HOST
  if host and not host:match('^https?://') then host = 'http://' .. host end
  host = host or 'http://localhost:11434'

  local messages = {}
  if opts.system then messages[1] = { role = 'system', content = opts.system } end
  for _, m in ipairs(opts.messages or {}) do messages[#messages + 1] = m end

  local body = vim.json.encode({
    model = opts.model,
    messages = messages,
    stream = false,
    keep_alive = '30m',
    options = { num_predict = opts.max_tokens or 1024, temperature = 0.2 },
  })

  return vim.system({
    'curl', '-sS', host .. '/api/chat',
    '-H', 'content-type: application/json',
    '--data-binary', '@-',
  }, { stdin = body, text = true }, function(res)
    if res.code ~= 0 then
      cb(nil, 'curl failed: ' .. (res.stderr or ('exit ' .. res.code)))
      return
    end
    local ok, decoded = pcall(vim.json.decode, res.stdout or '')
    if not ok or type(decoded) ~= 'table' then
      cb(nil, 'bad JSON from Ollama (is it running?)')
      return
    end
    if decoded.error then
      cb(nil, tostring(decoded.error))
      return
    end
    cb(decoded.message and decoded.message.content, nil)
  end)
end

return M
