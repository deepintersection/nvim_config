-- =============================================================================
-- lua/core/keymaps.lua — Global keymaps
-- =============================================================================
-- NEOVIM 0.12 DEFAULT KEYMAPS — DO NOT REMAP:
--   gra   → vim.lsp.buf.code_action()
--   gri   → vim.lsp.buf.implementation()
--   grn   → vim.lsp.buf.rename()
--   grr   → vim.lsp.buf.references()
--   grt   → vim.lsp.buf.type_definition()
--   grx   → vim.lsp.codelens.run()
--   gO    → vim.lsp.buf.document_symbol()
--   <C-S> (insert) → vim.lsp.buf.signature_help()
--   i_CTRL-R → literal register insert (do NOT remap)
--   gx    → textDocument/documentLink (new in 0.12)
-- =============================================================================

-- Convenience alias
local map = function(mode, lhs, rhs, opts)
  opts = vim.tbl_extend("force", { silent = true, noremap = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Leader keys — set BEFORE any plugin loads
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

-- =============================================================================
-- NORMAL MODE
-- =============================================================================

-- Better window navigation (avoids conflicts with gra/gri/etc.)
map("n", "<C-h>", "<C-w>h", { desc = "Window: left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window: down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window: up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window: right" })

-- Resize windows with arrows (avoids hjkl conflicts)
map("n", "<C-Up>",    "<cmd>resize +2<CR>",           { desc = "Window: taller" })
map("n", "<C-Down>",  "<cmd>resize -2<CR>",           { desc = "Window: shorter" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<CR>",  { desc = "Window: narrower" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>",  { desc = "Window: wider" })

-- Clear search highlight (keeps hlsearch=true but allows easy clear)
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Better n/N (always search forward/backward regardless of / or ?)
map("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next match" })
map("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev match" })

-- Save with <leader>w
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })

-- Quit helpers
map("n", "<leader>q", "<cmd>confirm quit<CR>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>confirm quitall<CR>", { desc = "Quit all" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Buffer: prev" })
map("n", "<S-l>", "<cmd>bnext<CR>",     { desc = "Buffer: next" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Buffer: delete" })
map("n", "<leader>bD", "<cmd>bdelete!<CR>", { desc = "Buffer: force delete" })

-- Move lines up/down in normal mode
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })

-- Keep cursor centred after jumps
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })

-- Join lines without moving cursor
map("n", "J", "mzJ`z", { desc = "Join lines (cursor stays)" })

-- Diagnostics navigation (use 0.12 vim.diagnostic API, not deprecated ones)
-- NOTE: [d / ]d are already mapped by 0.12 default.
-- We add a localised open float.
map("n", "<leader>e", function()
  vim.diagnostic.open_float(nil, { source = "if_many", border = "rounded" })
end, { desc = "Diagnostic: show float" })

map("n", "<leader>dl", function()
  vim.diagnostic.setloclist()
end, { desc = "Diagnostic: location list" })

-- Quickfix list navigation
map("n", "[q", "<cmd>cprevious<CR>", { desc = "Quickfix: prev" })
map("n", "]q", "<cmd>cnext<CR>",     { desc = "Quickfix: next" })
map("n", "<leader>co", "<cmd>copen<CR>",  { desc = "Quickfix: open" })
map("n", "<leader>cc", "<cmd>cclose<CR>", { desc = "Quickfix: close" })

-- Location list navigation
map("n", "[l", "<cmd>lprevious<CR>", { desc = "Loclist: prev" })
map("n", "]l", "<cmd>lnext<CR>",     { desc = "Loclist: next" })

-- Tabs
map("n", "<leader>tn", "<cmd>tabnew<CR>",   { desc = "Tab: new" })
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Tab: close" })
map("n", "]t", "<cmd>tabnext<CR>",          { desc = "Tab: next" })
map("n", "[t", "<cmd>tabprevious<CR>",      { desc = "Tab: prev" })

-- Open URL under cursor — 0.12: gx is now an LSP-aware built-in.
-- We keep 'gx' free and only add a fallback for non-LSP contexts via <leader>gx.
-- (do NOT remap gx)

-- Clipboard: explicit yank to system clipboard (avoids global clipboard=unnamedplus)
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map("n",          "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })

-- Do not yank on x / c in normal mode
map("n", "x", '"_x', { desc = "Delete char (no yank)" })

-- =============================================================================
-- VISUAL MODE
-- =============================================================================

-- Stay in visual mode after indent
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move selected lines
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Do not yank replaced text (paste over selection)
map("v", "p", '"_dP', { desc = "Paste without yanking selection" })

-- Clipboard
map("v", "<leader>y", '"+y', { desc = "Yank selection to system clipboard" })

-- =============================================================================
-- INSERT MODE
-- =============================================================================

-- i_CTRL-R — DO NOT REMAP (0.12: literal insert, 10× faster)
-- i_CTRL-S — DO NOT REMAP (0.12: LSP signature help)

-- Quick escape alternative (jk) — optional, low-conflict
map("i", "jk", "<Esc>", { desc = "Escape (jk shortcut)" })

-- =============================================================================
-- TERMINAL MODE
-- =============================================================================

-- Exit terminal mode with <Esc><Esc>
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: exit mode" })

-- Window nav from terminal
map("t", "<C-h>", "<cmd>wincmd h<CR>", { desc = "Terminal: window left" })
map("t", "<C-j>", "<cmd>wincmd j<CR>", { desc = "Terminal: window down" })
map("t", "<C-k>", "<cmd>wincmd k<CR>", { desc = "Terminal: window up" })
map("t", "<C-l>", "<cmd>wincmd l<CR>", { desc = "Terminal: window right" })


local sel  = require("nvim-treesitter-textobjects.select")
local move = require("nvim-treesitter-textobjects.move")
local swap = require("nvim-treesitter-textobjects.swap")

local function s(query, group)
  -- group defaults to "textobjects"; "locals" for @local.scope
  return function()
    sel.select_textobject(query, group or "textobjects")
  end
end

-- -----------------------------------------------------------------------
-- TEXT OBJECT SELECT keymaps (x=visual, o=operator-pending)
--
-- Keymap choices — conflict table:
--   af/if  — free (built-in ftplugins use ]] [[ for nav, not af/if)
--   ac/ic  — free (no 0.12 default uses these)
--   aa/ia  — free
--   ao/io  — free (o for loop/outer avoids al/il clash with loclist]l[l)
--   ai/ii  — free
--   a=/i=  — free
--   ar/ir  — free
--   as     — free (scope, uses "locals" query group)
-- -----------------------------------------------------------------------
local to_maps = {
  -- Functions / methods
  { "af", "@function.outer" }, { "if", "@function.inner" },
  -- Classes
  { "ac", "@class.outer" },    { "ic", "@class.inner" },
  -- Arguments / parameters
  { "aa", "@parameter.outer" },{ "ia", "@parameter.inner" },
  -- Loops  (using 'o' not 'l' — 'l' clashes with loclist nav [l/]l)
  { "ao", "@loop.outer" },     { "io", "@loop.inner" },
  -- Conditionals
  { "ai", "@conditional.outer" }, { "ii", "@conditional.inner" },
  -- Assignments
  { "a=", "@assignment.outer" },  { "i=", "@assignment.inner" },
  -- Return statements
  { "ar", "@return.outer" },   { "ir", "@return.inner" },
}
for _, m in ipairs(to_maps) do
  vim.keymap.set({ "x", "o" }, m[1], s(m[2]),
    { desc = "TS select: " .. m[2], silent = true })
end

-- Scope (uses "locals" query group, not "textobjects")
vim.keymap.set({ "x", "o" }, "as", function()
  sel.select_textobject("@local.scope", "locals")
end, { desc = "TS select: scope", silent = true })

-- -----------------------------------------------------------------------
-- MOVEMENT keymaps (n/x/o modes)
--
-- Conflict table:
--   ]f [f ]F [F  — free
--   ]C [C ]E [E  — free (uppercase avoids gitsigns ]c/[c)
--   ]a [a        — free
--   ]o [o        — free (o=loop, avoids ]l/[l loclist conflict)
--   ]i [i        — free
-- -----------------------------------------------------------------------
local function mv(dir, end_or_start, query)
  local method = (dir == "next" and "goto_next_" or "goto_previous_")
              .. (end_or_start == "end" and "end" or "start")
  return function()
    move[method](query, "textobjects")
  end
end

local move_maps = {
  -- Next start
  { "]f", "next", "start", "@function.start"    },
  { "]C", "next", "start", "@class.start"       },
  { "]a", "next", "start", "@parameter.inner"   },
  { "]o", "next", "start", "@loop.outer"        },
  { "]i", "next", "start", "@conditional.outer" },
  -- Next end
  { "]F", "next", "end",   "@function.end"      },
  { "]E", "next", "end",   "@class.end"         },
  -- Prev start
  { "[f", "prev", "start", "@function.start"    },
  { "[C", "prev", "start", "@class.start"       },
  { "[a", "prev", "start", "@parameter.inner"   },
  { "[o", "prev", "start", "@loop.outer"        },
  { "[i", "prev", "start", "@conditional.outer" },
  -- Prev end
  { "[F", "prev", "end",   "@function.end"      },
  { "[E", "prev", "end",   "@class.end"         },
}

for _, m in ipairs(move_maps) do
  local lhs, dir, es, query = m[1], m[2], m[3], m[4]
  local desc = ("TS: %s %s %s"):format(dir, es, query)
  vim.keymap.set({ "n", "x", "o" }, lhs, mv(dir, es, query),
    { desc = desc, silent = true })
end

-- -----------------------------------------------------------------------
-- SWAP keymaps
-- -----------------------------------------------------------------------
vim.keymap.set("n", "<leader>csn", function()
  swap.swap_next("@parameter.inner", "textobjects")
end, { desc = "TS: swap next argument", silent = true })

vim.keymap.set("n", "<leader>csp", function()
  swap.swap_previous("@parameter.inner", "textobjects")
end, { desc = "TS: swap prev argument", silent = true })

-- -----------------------------------------------------------------------
-- Repeatable ; and , for TS movements
-- (uses the repeatable_move module bundled with textobjects)
-- -----------------------------------------------------------------------
local ok, rep = pcall(require, "nvim-treesitter-textobjects.repeatable_move")
if ok then
  vim.keymap.set({ "n", "x", "o" }, ";",
    rep.repeat_last_move_next, { desc = "TS: repeat move next" })
  vim.keymap.set({ "n", "x", "o" }, ",",
    rep.repeat_last_move_previous, { desc = "TS: repeat move prev" })
  -- Keep f/F/t/T repeatable through the same system
  vim.keymap.set({ "n", "x", "o" }, "f", rep.builtin_f_expr, { expr = true })
  vim.keymap.set({ "n", "x", "o" }, "F", rep.builtin_F_expr, { expr = true })
  vim.keymap.set({ "n", "x", "o" }, "t", rep.builtin_t_expr, { expr = true })
  vim.keymap.set({ "n", "x", "o" }, "T", rep.builtin_T_expr, { expr = true })
end






	-- keymaps
	-- You can use the capture groups defined in `textobjects.scm`
	vim.keymap.set({ "x", "o" }, "am", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@function.outer", "textobjects")
	end)
	vim.keymap.set({ "x", "o" }, "im", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@function.inner", "textobjects")
	end)
	vim.keymap.set({ "x", "o" }, "ac", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@class.outer", "textobjects")
	end)
	vim.keymap.set({ "x", "o" }, "ic", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@class.inner", "textobjects")
	end)
	-- You can also use captures from other query groups like `locals.scm`
	vim.keymap.set({ "x", "o" }, "as", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@local.scope", "locals")
	end)
-- =============================================================================
-- LEADER GROUPS (used by which-key, documented here for reference)
-- =============================================================================
-- <leader>b   → buffer operations
-- <leader>c   → code / LSP (non-default actions only)
-- <leader>d   → diagnostics
-- <leader>f   → find / files (fzf-lua)
-- <leader>g   → git
-- <leader>l   → language / lint
-- <leader>q   → quit
-- <leader>s   → search / replace
-- <leader>t   → tabs / terminal
-- <leader>u   → ui toggles
-- <leader>w   → window / write
-- <leader>x   → trouble / lists
