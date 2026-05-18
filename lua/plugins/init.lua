-- =============================================================================
-- lua/plugins/init.lua — lazy.nvim bootstrap and plugin manifest
-- =============================================================================
-- lazy.nvim is chosen over vim.pack (0.12 built-in, still experimental) for:
--   · Mature lazy-loading (critical for SSH performance)
--   · Event/condition/ft/cmd-based loading
--   · Plugin locking via lazy-lock.json
-- =============================================================================

-- Bootstrap: install lazy.nvim if not present
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.notify("[lazy] Cloning lazy.nvim …", vim.log.levels.INFO)
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("[lazy] Failed to clone lazy.nvim:\n" .. out, vim.log.levels.ERROR)
    return
  end
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------
-- Plugin specification — each file returns a table (or list of tables)
-- that lazy.nvim merges into a single spec.
-- -----------------------------------------------------------------------------
require("lazy").setup({
  -- Split across files for modularity:
  { import = "plugins.treesitter" },
  { import = "plugins.lsp" },
  { import = "plugins.editor" },
  { import = "plugins.ui" },
  { import = "plugins.completion" },
--  { import = "plugins.dap" },
  { import = "plugins.git" },
--  { import = "plugins.tools" },
--  -- Language-specific:
--  { import = "plugins.lang.python" },
--  { import = "plugins.lang.rust" },
--  { import = "plugins.lang.lua_lang" },
--  { import = "plugins.lang.embedded" },
}, {
  -- -----------------------------------------------------------------------------
  -- lazy.nvim global options
  -- -----------------------------------------------------------------------------
  defaults = {
    lazy = true,      -- default: load plugins lazily
    version = false,  -- track HEAD unless plugin specifies version
  },
  install = {
    colorscheme = { "catppuccin", "habamax" }, -- fallback colorschemes on install
  },
  checker = {
    enabled = false,  -- disable automatic update checking (noisy over SSH)
  },
  change_detection = {
    enabled = true,
    notify  = false,  -- don't notify on config change
  },
  performance = {
    rtp = {
      -- Disable built-in plugins we don't need (saves startup time)
      disabled_plugins = {
        "gzip", "matchit", "matchparen", "netrwPlugin",
        "rplugin", "tarPlugin", "tohtml",   -- moved to opt in 0.12
        "tutor", "zipPlugin",
        "2html_plugin", "getscript", "getscriptPlugin",
        "logiPat", "vimball", "vimballPlugin",
      },
    },
  },
  ui = {
    border = "rounded",
    size   = { width = 0.85, height = 0.85 },
  },
  -- Lock file location
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
})
