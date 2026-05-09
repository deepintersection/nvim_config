-- =============================================================================
--  init.lua — entry point
--  Load order matters: options → keymaps → autocmds → plugins
--  Environment is expected to be pre-set by the launch script.
-- =============================================================================

-- Expose a global helper used throughout the config
---@param msg string
---@param level? integer  vim.log.levels.*
_G.notify = function(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-config" })
end

-- Core (no plugins, no side-effects beyond vim.opt / vim.keymap)
require("config.options")

-- Feature flags for optional components (set to false to disable)
local enable_keymaps = true
local enable_autocmds = true

if enable_keymaps then
  require("config.keymaps")
end

if enable_autocmds then
  require("config.autocmds")
end

-- Plugin manager bootstrap — loads plugins only when the file exists
require("config.lazy")
