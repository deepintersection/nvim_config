-- =============================================================================
--  config/options.lua — vim.opt settings
--  No plugin dependencies. Safe to load before lazy.nvim.
-- =============================================================================

local opt = vim.opt

-- ----------------------------------------------------------------------------
-- Leader keys (must be set before any keymaps / plugins)
-- ----------------------------------------------------------------------------
vim.g.mapleader      = " "   -- <Space>
vim.g.maplocalleader = "\\"  -- <Backslash>

-- ----------------------------------------------------------------------------
-- UI
-- ----------------------------------------------------------------------------
opt.number         = true    -- absolute line numbers
opt.relativenumber = true    -- + relative
opt.signcolumn     = "yes"   -- always show; prevents layout shift
opt.cursorline     = true
opt.colorcolumn    = "100"
opt.termguicolors  = true    -- 24-bit colour (required by most themes)
opt.showmode       = false   -- mode is shown in statusline instead
opt.laststatus     = 3       -- global statusline (Neovim 0.7+)
opt.cmdheight      = 1
opt.pumheight      = 12      -- completion popup max items
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.splitbelow     = true
opt.splitright     = true
opt.conceallevel   = 0       -- never hide characters (important for JSON etc.)
opt.list           = true
opt.listchars      = {
  tab      = "→ ",
  trail    = "·",
  nbsp     = "␣",
  extends  = "»",
  precedes = "«",
}

-- ----------------------------------------------------------------------------
-- Editing
-- ----------------------------------------------------------------------------
opt.expandtab   = true   -- spaces, not tabs
opt.tabstop     = 4
opt.shiftwidth  = 4
opt.softtabstop = 4
opt.smartindent = true
opt.wrap        = false
opt.linebreak   = true   -- soft-wrap at word boundary when wrap is on
opt.breakindent = true

-- ----------------------------------------------------------------------------
-- Search
-- ----------------------------------------------------------------------------
opt.ignorecase = true
opt.smartcase  = true    -- override ignorecase when pattern has uppercase
opt.hlsearch   = false   -- don't keep search highlight after moving
opt.incsearch  = true

-- ----------------------------------------------------------------------------
-- Files / buffers
-- ----------------------------------------------------------------------------
opt.hidden      = true   -- allow unsaved buffers in background
opt.undofile    = true   -- persistent undo
opt.swapfile    = false
opt.backup      = false
opt.updatetime  = 250    -- ms before CursorHold fires (affects gitsigns etc.)
opt.timeoutlen  = 400    -- ms to wait for mapped sequence

-- Store undo files in a dedicated location, not next to the source file
local undo_dir = vim.fn.stdpath("data") .. "/undo"
if vim.fn.isdirectory(undo_dir) == 0 then
  vim.fn.mkdir(undo_dir, "p")
end
opt.undodir = undo_dir

-- ----------------------------------------------------------------------------
-- Clipboard
-- ----------------------------------------------------------------------------
-- We do NOT set clipboard=unnamedplus globally; instead we provide explicit
-- keymaps for system-clipboard operations to avoid surprises in remote/SSH.
-- Override by setting NVIM_CLIPBOARD=1 in the launch script if wanted.
if vim.env.NVIM_CLIPBOARD == "1" then
  opt.clipboard = "unnamedplus"
end

-- ----------------------------------------------------------------------------
-- Completion
-- ----------------------------------------------------------------------------
opt.completeopt = { "menu", "menuone", "noselect" }

-- ----------------------------------------------------------------------------
-- Folds (using expr provider; treesitter will override when loaded)
-- ----------------------------------------------------------------------------
opt.foldmethod     = "expr"
opt.foldexpr       = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99   -- open all folds by default
opt.foldenable     = true

-- ----------------------------------------------------------------------------
-- Grep / search backend
-- Prefer ripgrep; fall back to grep.
-- ----------------------------------------------------------------------------
if vim.fn.executable("rg") == 1 then
  opt.grepprg    = "rg --vimgrep --smart-case"
  opt.grepformat = "%f:%l:%c:%m"
end

-- ----------------------------------------------------------------------------
-- Netrw (built-in file browser) — disable; we'll use a plugin tree
-- ----------------------------------------------------------------------------
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

-- ----------------------------------------------------------------------------
-- Python provider
-- Reads NVIM_PYTHON3 from environment (set in launch script).
-- Falls back to 'python3' on PATH so plain usage still works.
-- ----------------------------------------------------------------------------
if vim.env.NVIM_PYTHON3 and vim.env.NVIM_PYTHON3 ~= "" then
  vim.g.python3_host_prog = vim.env.NVIM_PYTHON3
else
  vim.g.python3_host_prog = vim.fn.exepath("python3")
end

-- Disable providers we don't use (speeds up startup)
vim.g.loaded_ruby_provider   = 0
vim.g.loaded_perl_provider   = 0
vim.g.loaded_node_provider   = 0  -- remove if you add JS/TS later
