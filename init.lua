-- =============================================================================
--  init.lua — entry point
--  Load order matters: options → keymaps → autocmds → plugins
--  Environment is expected to be pre-set by the launch script.
-- =============================================================================

-- Safety: hard-fail with a readable message if Neovim is too old
if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("Requires Neovim >= 0.10", vim.log.levels.ERROR)
  return
end

-- Expose a global helper used throughout the config
---@param msg string
---@param level? integer  vim.log.levels.*
_G.notify = function(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-config" })
end

-- Core (no plugins, no side-effects beyond vim.opt / vim.keymap)
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Plugin manager bootstrap — loads plugins only when the file exists
require("config.lazy")
