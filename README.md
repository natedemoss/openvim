# openvim

A Neovim distribution with AI built in. It boots plain Neovim against a bundled
config that adds inline autocomplete (Copilot-style ghost text) with a
pluggable model backend: **Claude**, **Ollama** (local), or **OpenAI**.

openvim does not fork Neovim's C core. It is a config + plugin layer, so it
tracks upstream Neovim for free and stays easy to hack on in Lua.

## Requirements

- Neovim 0.10+ (uses `vim.system` and inline virtual text)
- `curl` on PATH
- An API key for your chosen backend, or a running Ollama server

## Run it

Windows (PowerShell):

```powershell
.\bin\openvim.ps1
```

Windows (cmd) or after putting `bin/` on PATH:

```cmd
openvim
```

macOS / Linux:

```sh
./bin/openvim
```

Or directly:

```sh
nvim -u config/init.lua
```

## Backends

Pick a provider via env or at runtime.

```sh
# Claude (default)
setx ANTHROPIC_API_KEY "sk-ant-..."      # Windows
export ANTHROPIC_API_KEY=sk-ant-...      # unix

# OpenAI
export OPENAI_API_KEY=sk-...

# Ollama (local, no key) — pull a code model first:
ollama pull qwen2.5-coder:1.5b-base   # base = real fill-in-the-middle, fast on CPU
```

Choose the default without editing code:

```sh
OPENVIM_PROVIDER=ollama openvim
```

## Features

### Inline autocomplete
- Start typing in insert mode. After you pause, ghost text appears.
- `<Tab>` accepts the suggestion (falls back to a real tab if none is shown).
- `<C-]>` dismisses it.

### Inline edit
- Select lines in visual mode, press `<leader>ae` (leader is space), type an
  instruction ("add error handling", "convert to async"), and the selection is
  rewritten in place.
- Or `:'<,'>OpenvimEdit make this iterative` on a range.

### Agent (`:chat`)
- `:chat <instruction>` sends the whole current file plus your instruction to
  the model and applies the rewritten file directly to the buffer.
- Example: `:chat add error handling and a docstring`
- (Vim requires capitalized commands, so `:Chat` is the real command; `:chat`
  is wired as an abbreviation to it.)

## Commands

| Command             | Description                          |
|---------------------|--------------------------------------|
| `:OpenvimToggle`    | Enable/disable inline autocomplete   |
| `:OpenvimProvider`  | Switch backend (`claude`/`ollama`/`openai`) |
| `:OpenvimStatus`    | Show current provider, model, debounce |
| `:OpenvimEdit`      | AI-edit the selected lines (range)   |
| `:chat` / `:Chat`   | Agent: edit the whole current file from an instruction |

## Configure

Override defaults by editing `config/lua/openvim/init.lua`, or pass a table to
`setup()`:

```lua
require('openvim').setup({
  ai = {
    provider = 'ollama',
    debounce_ms = 250,
    models = { ollama = 'qwen2.5-coder:1.5b-base' },
  },
})
```

## Layout

```
openvim/
  bin/openvim(.ps1/.cmd)        launchers
  config/init.lua               entry point (nvim -u)
  config/lua/openvim/
    init.lua                    defaults + branding + setup
    ai/init.lua                 commands + wiring
    ai/complete.lua             ghost-text engine
    ai/backends/                claude.lua, ollama.lua, openai.lua
```

## Roadmap

- [x] Inline autocomplete (ghost text, pluggable backend)
- [x] Inline edit (select + describe + rewrite)
- [x] Agent `:chat` (edits the current file in place)
- [ ] Agent tool use (multi-file edits, run commands)
- [ ] Streaming completions and chat
- [ ] Per-filetype enable/disable
