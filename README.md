<div align="center">

# openvim

**A Neovim distribution with AI built in.**

Inline autocomplete, inline edit, and an agent that edits your code from a command.
Bring your own model: Claude, a local Ollama model, or OpenAI.

![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-2C2D72?logo=lua&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)

</div>

---

openvim is not a fork of Neovim's C core. It is a config and plugin layer that
boots plain Neovim against a bundled setup, so it tracks upstream Neovim for
free and stays easy to hack on in pure Lua.

## Features

- **Inline autocomplete** Copilot-style ghost text as you type. `<Tab>` to accept.
- **Inline edit** Select code, describe a change, get it rewritten in place.
- **`:chat` agent** Tell it what to do and it edits the current file directly.
- **Pluggable backends** Claude, Ollama (local, free), or OpenAI. Your choice persists.

## Quick start

```sh
git clone https://github.com/natedemoss/openvim
cd openvim

# pick a backend (see "Models" below), then:
nvim -u config/init.lua
```

Requirements: Neovim 0.10+ and `curl` on PATH.

### Run it as `openvim`

Put `bin/` on your PATH, then launch with one word:

```sh
openvim
```

| Platform        | Launcher              |
|-----------------|-----------------------|
| Windows (PS)    | `bin\openvim.ps1`     |
| Windows (cmd)   | `bin\openvim.cmd`     |
| macOS / Linux   | `bin/openvim`         |

## Backends

Pick a provider once and openvim remembers it (`:OpenvimProvider`, saved to
`~/.openvim/settings.json`).

```sh
# Claude (best quality)
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI
export OPENAI_API_KEY=sk-...

# Ollama (local, free, private) — see models below
```

## Models (Ollama)

openvim uses two kinds of model: a **base** model for autocomplete
(fill-in-the-middle) and an **instruct** model for `:chat` and inline edit.
[Qwen2.5-Coder](https://ollama.com/library/qwen2.5-coder) is the best local
code family right now. Pick a size to match your hardware.

### Autocomplete (base / FIM)

| Model                          | Size  | Best for                          |
|--------------------------------|-------|-----------------------------------|
| `qwen2.5-coder:0.5b-base`      | 0.5 GB| CPU-only, snappiest (~1s)         |
| `qwen2.5-coder:1.5b-base`      | 1.0 GB| CPU with a little patience        |
| `qwen2.5-coder:3b-base`        | 1.9 GB| light GPU                         |
| `qwen2.5-coder:7b-base`        | 4.7 GB| GPU, best quality                 |

### Chat + inline edit (instruct)

| Model                          | Size  | Best for                          |
|--------------------------------|-------|-----------------------------------|
| `qwen2.5-coder:1.5b`           | 1.0 GB| CPU, quick answers                |
| `qwen2.5-coder:7b`             | 4.7 GB| balanced quality (GPU recommended)|
| `qwen2.5-coder:14b`            | 9.0 GB| high quality, needs a real GPU    |
| `deepseek-coder-v2:16b`        | 8.9 GB| strong alternative                |

```sh
# CPU-friendly default pairing:
ollama pull qwen2.5-coder:0.5b-base   # autocomplete
ollama pull qwen2.5-coder:1.5b        # chat / edit
```

> On a CPU-only machine, use the small base model for autocomplete. A 7B
> instruct model on CPU can take minutes per response. A GPU changes everything.

## Usage

### Autocomplete
Type in insert mode, pause, and ghost text appears. `<Tab>` accepts, `<C-]>` dismisses.

### Inline edit
Visually select lines, press `<leader>ae` (leader is space), and type an instruction:

```
add input validation
```

### `:chat` agent
Open a file and tell openvim what to change. It rewrites the file in place.

```vim
:chat add type hints and a docstring
:chat refactor this into smaller functions
```

## Commands

| Command             | Description                                       |
|---------------------|---------------------------------------------------|
| `:chat` / `:Chat`   | Agent: edit the current file from an instruction  |
| `:OpenvimEdit`      | AI-edit the selected lines (use a visual range)   |
| `:OpenvimToggle`    | Enable / disable inline autocomplete              |
| `:OpenvimProvider`  | Switch backend (`claude` / `ollama` / `openai`)   |
| `:OpenvimStatus`    | Show current provider, model, and settings        |

## Configuration

Defaults live in `config/lua/openvim/init.lua`. Override with a table:

```lua
require('openvim').setup({
  ai = {
    provider = 'ollama',
    debounce_ms = 250,
    models      = { ollama = 'qwen2.5-coder:1.5b-base' }, -- autocomplete
    chat_models = { ollama = 'qwen2.5-coder:7b' },        -- chat / edit
  },
})
```

## How it works

```
openvim/
  bin/                  launchers (openvim, .ps1, .cmd)
  config/init.lua       entry point (nvim -u)
  config/lua/openvim/
    init.lua            defaults, branding, setup
    dashboard.lua       start screen
    settings.lua        persisted user settings
    ai/
      complete.lua      ghost-text autocomplete engine
      edit.lua          inline edit on a selection
      agent.lua         :chat whole-file agent
      backends/         claude.lua, ollama.lua, openai.lua
```

Backends expose two calls: `complete()` for fill-in-the-middle autocomplete and
`ask()` for instruction-following chat and edits.

## Roadmap

- [x] Inline autocomplete (ghost text, pluggable backend)
- [x] Inline edit (select, describe, rewrite)
- [x] `:chat` agent (edits the current file in place)
- [ ] Agent tool use (multi-file edits, run commands)
- [ ] Streaming completions and chat
- [ ] Per-filetype enable / disable

## License

MIT
