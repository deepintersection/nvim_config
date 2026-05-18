-- =============================================================================
-- All options are set explicitly. No automatic detection.
-- Environment variables consumed here:
--   NVIM_THEME          — colorscheme name (optional, default handled in ui.lua)
--   NVIM_PYTHON_PATH    — explicit python3 provider path
-- =============================================================================

local opt = vim.opt

-- -----------------------------------------------------------------------------
-- Performance (critical for SSH)
-- -----------------------------------------------------------------------------
opt.updatetime  = 250        -- faster CursorHold events (ms)
opt.timeoutlen  = 400        -- key sequence timeout (ms)
opt.ttimeoutlen = 200         -- terminal key code timeout (ms)
opt.lazyredraw  = false      -- NOTE: incompatible with some plugins; keep false
opt.synmaxcol   = 300        -- syntax highlight only first N columns per line
opt.redrawtime  = 1500       -- stop highlighting if it takes too long

-- -----------------------------------------------------------------------------
-- Files & encoding
-- -----------------------------------------------------------------------------
opt.encoding    = "utf-8"
opt.fileencoding = "utf-8"
opt.fileformats = "unix,dos,mac"
opt.backup      = false
opt.writebackup = false
opt.swapfile    = false
opt.undofile    = true       -- persistent undo
opt.undolevels  = 10000

-- Undo directory — OS-aware
local undodir = vim.fn.stdpath("data") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

-- -----------------------------------------------------------------------------
-- UI
-- -----------------------------------------------------------------------------
opt.termguicolors = true     -- true-colour (set $COLORTERM=truecolor in SSH)
opt.background    = "dark"
opt.number        = true
opt.relativenumber = true
opt.signcolumn    = "yes:1"  -- always 1-wide; avoids layout shift
opt.cursorline    = true
opt.cursorlineopt = "number" -- only highlight the line number, not the whole line
opt.colorcolumn   = "88,120" -- Python PEP8 / practical limit
opt.wrap          = false
opt.linebreak     = true
opt.showbreak     = "↪ "
opt.scrolloff     = 8
opt.sidescrolloff = 8
opt.cmdheight     = 1        -- keep to 1; use noice/messages for overflow
opt.showmode      = false    -- statusline shows mode
opt.showcmd       = false    -- avoids flickering over SSH
opt.ruler         = false
opt.showtabline   = 1        -- show tabline only when >1 tab
opt.laststatus    = 3        -- global statusline (0.7+)
opt.splitbelow    = true
opt.splitright    = true
opt.equalalways   = false    -- don't auto-resize splits

-- 0.12: new statusline helpers are available (vim.lsp.status / vim.diagnostic.status)
-- configured in plugins/ui.lua

-- -----------------------------------------------------------------------------
-- Search
-- -----------------------------------------------------------------------------
opt.hlsearch   = true
opt.incsearch  = true
opt.ignorecase = true
opt.smartcase  = true        -- case-sensitive when uppercase present
opt.grepprg    = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"

-- -----------------------------------------------------------------------------
-- Indentation & whitespace
-- -----------------------------------------------------------------------------
opt.expandtab   = true       -- spaces by default (override per filetype)
opt.tabstop     = 4
opt.shiftwidth  = 4
opt.softtabstop = 4
opt.smartindent = true
opt.shiftround  = true
opt.list        = true
opt.listchars   = {
  tab      = "→ ",
  trail    = "·",
  nbsp     = "␣",
  extends  = "›",
  precedes = "‹",
}

-- -----------------------------------------------------------------------------
-- Completion (0.12 native)
-- -----------------------------------------------------------------------------
-- blink.cmp manages completeopt at runtime; we set a sane default here.
opt.completeopt  = "menu,menuone,noselect"
opt.pumheight    = 15
opt.pummaxwidth  = 50        -- 0.12 new option
opt.pumborder    = "rounded" -- 0.12 new option
opt.pumblend     = 0         -- no transparency (SSH terminals often don't support it)
-- Native autocomplete (0.12): disabled — we use blink.cmp
-- opt.autocomplete = false   -- uncomment only if you want to explicitly disable

-- -----------------------------------------------------------------------------
-- Folding  (treesitter-based, configured later)
-- -----------------------------------------------------------------------------
opt.foldmethod  = "manual"   -- start manual; plugins switch to expr
opt.foldlevel   = 99         -- open all folds by default
opt.foldenable  = false

-- -----------------------------------------------------------------------------
-- Clipboard
-- -----------------------------------------------------------------------------
-- NOTE: over SSH, clipboard integration requires OSC 52 or tmux passthrough.
-- Do NOT set clipboard=unnamedplus globally for SSH sessions —
-- it causes visible delays. Use explicit keymaps instead (set in keymaps.lua).
opt.clipboard = ""           -- empty: use Neovim's internal registers by default

-- The launch script sets NVIM_CLIPBOARD=1 if clipboard should be enabled.
if vim.env.NVIM_CLIPBOARD == "1" then
  opt.clipboard = "unnamedplus"
end

-- -----------------------------------------------------------------------------
-- Provider paths (set from launch script, never auto-detected)
-- -----------------------------------------------------------------------------
-- NVIM_PYTHON_PATH must be set in the launch script if Python provider is needed.
if vim.env.NVIM_PYTHON_PATH and vim.env.NVIM_PYTHON_PATH ~= "" then
  vim.g.python3_host_prog = vim.env.NVIM_PYTHON_PATH
else
  -- Disable Python provider to avoid slow startup when not explicitly configured
  vim.g.loaded_python3_provider = 0
end

-- Always disable providers we don't use
vim.g.loaded_ruby_provider   = 0
vim.g.loaded_perl_provider   = 0
vim.g.loaded_node_provider   = 0

-- -----------------------------------------------------------------------------
-- Spell
-- -----------------------------------------------------------------------------
opt.spell     = false        -- enable per filetype (markdown, text, gitcommit)
opt.spelllang = { "en_us" }

-- -----------------------------------------------------------------------------
-- Mouse
-- -----------------------------------------------------------------------------
opt.mouse     = ""          -- mouse in all modes; useful for SSH pane resizing

-- -----------------------------------------------------------------------------
-- Misc
-- -----------------------------------------------------------------------------
opt.hidden         = true    -- allow unsaved buffers in background
opt.confirm        = true    -- ask to save instead of error
opt.joinspaces     = false   -- no double space after period on join
opt.virtualedit    = "block" -- true block selection
opt.whichwrap      = "b,s"   -- only b and s wrap lines (avoid arrow key wrapping)
opt.iskeyword:append("-")    -- treat hyphenated-words as one word
opt.shortmess:append("c")   -- no "match x of y" completion messages
opt.shortmess:append("I")   -- no intro screen
opt.formatoptions  = "jcroqlnt" -- see :help fo-table
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions"

-- 0.12: wildchar now supports /, ?, :g, :v, :vimgrep completion
opt.wildmode  = "longest:full,full"
opt.wildignorecase = true
opt.wildignore:append({ "*.pyc", "__pycache__", ".git", "*.o", "*.a", "node_modules" })

-- Diff
opt.diffopt:append("linematch:60")
