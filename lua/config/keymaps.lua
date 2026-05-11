-- =============================================================================
--  config/keymaps.lua — base keymaps (no plugin dependencies)
--
--  Convention used throughout the whole config:
--    <leader>   = Space  (set in options.lua)
--    <localleader> = \
--
--  Namespace allocation (reserved for plugins — do NOT overlap here):
--    <leader>f  → Telescope / fuzzy-find
--    <leader>g  → Git
--    <leader>l  → LSP
--    <leader>d  → Debug / diagnostics
--    <leader>t  → Terminal
--    <leader>u  → UI toggles
--    <leader>x  → Trouble / quickfix
--    <leader>p  → Plugin manager (lazy)
--    <leader>s  → Search/replace (spectre)
--    <leader>b  → Buffer management
-- =============================================================================

local map = vim.keymap.set

-- ----------------------------------------------------------------------------
-- Editing convenience
-- ----------------------------------------------------------------------------

-- Keep cursor centred after n/N/J
map("n", "n",     "nzzzv",            { desc = "Next match (centred)" })
map("n", "N",     "Nzzzv",            { desc = "Prev match (centred)" })
map("n", "J",     "mzJ`z",            { desc = "Join lines (keep cursor)" })

-- Move lines in visual mode
map("v", "J",     ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K",     ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Indent and stay in visual mode
map("v", "<",     "<gv",              { desc = "Indent left" })
map("v", ">",     ">gv",              { desc = "Indent right" })

-- Paste without overwriting unnamed register
map("x", "<leader>P", '"_dP',         { desc = "Paste without yanking" })

-- Delete without yanking
map({ "n", "v" }, "<leader>D", '"_d', { desc = "Delete without yanking" })

-- ----------------------------------------------------------------------------
-- Clipboard (explicit; only when needed — avoids surprises over SSH)
-- ----------------------------------------------------------------------------
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map("n",          "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

-- ----------------------------------------------------------------------------
-- Window navigation (no plugins needed)
-- ----------------------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })

-- Resize with arrows
map("n", "<C-Up>",    ":resize +2<CR>",          { desc = "Window taller", silent = true })
map("n", "<C-Down>",  ":resize -2<CR>",          { desc = "Window shorter", silent = true })
map("n", "<C-Left>",  ":vertical resize -2<CR>", { desc = "Window narrower", silent = true })
map("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Window wider", silent = true })

-- ----------------------------------------------------------------------------
-- Buffer navigation
-- ----------------------------------------------------------------------------
map("n", "<S-h>", ":bprevious<CR>", { desc = "Prev buffer", silent = true })
map("n", "<S-l>", ":bnext<CR>",     { desc = "Next buffer", silent = true })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Close buffer", silent = true })

-- ----------------------------------------------------------------------------
-- Quickfix / location list
-- ----------------------------------------------------------------------------
map("n", "<leader>qn", ":cnext<CR>",     { desc = "Quickfix next" })
map("n", "<leader>qp", ":cprev<CR>",     { desc = "Quickfix prev" })
map("n", "<leader>qo", ":copen<CR>",     { desc = "Quickfix open" })
map("n", "<leader>qc", ":cclose<CR>",    { desc = "Quickfix close" })

-- ----------------------------------------------------------------------------
-- Misc
-- ----------------------------------------------------------------------------
-- Clear search highlight
map("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search highlight", silent = true })

-- Save with Ctrl-S (terminal must pass it through)
map({ "n", "i", "v" }, "<C-s>", "<Esc>:w<CR>", { desc = "Save file", silent = true })

-- Quit shortcuts
map("n", "<leader>qq", ":qa<CR>",  { desc = "Quit all" })
map("n", "<leader>qw", ":wqa<CR>", { desc = "Write + quit all" })

-- Open config directory fast
map("n", "<leader>oc", function()
  vim.cmd("e " .. vim.fn.stdpath("config"))
end, { desc = "Open nvim config dir" })
