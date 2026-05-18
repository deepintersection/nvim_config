-- Load core settings first (no plugin dependencies)
-- Leader keys — set BEFORE any plugin loads
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"
require('vim._core.ui2').enable({})

require("core.options")
require("core.autocmds")
require("core.treesitter")
require("plugins")
require("core.keymaps")
