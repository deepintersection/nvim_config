-- =============================================================================
--  config/autocmds.lua — autocommands (no plugin dependencies)
-- =============================================================================

local function augroup(name)
  return vim.api.nvim_create_augroup("nvimcfg_" .. name, { clear = true })
end

-- ----------------------------------------------------------------------------
-- Highlight on yank
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
  group    = augroup("yank_highlight"),
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 350 })
  end,
})

-- ----------------------------------------------------------------------------
-- Restore cursor position when opening a file
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufReadPost", {
  group    = augroup("restore_cursor"),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ----------------------------------------------------------------------------
-- Trim trailing whitespace on save (opt-in via b:trim_whitespace = true)
-- For now enabled for all text/code filetypes except binary-like ones.
-- ----------------------------------------------------------------------------
local no_trim_ft = { "markdown", "text", "diff", "gitcommit" }

vim.api.nvim_create_autocmd("BufWritePre", {
  group    = augroup("trim_whitespace"),
  callback = function()
    if vim.tbl_contains(no_trim_ft, vim.bo.filetype) then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- ----------------------------------------------------------------------------
-- Per-filetype overrides (indentation, etc.)
-- Keeps them here so options.lua stays generic.
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("filetype_overrides"),
  pattern = { "lua" },
  callback = function()
    vim.opt_local.tabstop     = 2
    vim.opt_local.shiftwidth  = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("filetype_overrides_yaml"),
  pattern = { "yaml", "toml", "json", "jsonc" },
  callback = function()
    vim.opt_local.tabstop     = 2
    vim.opt_local.shiftwidth  = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("filetype_overrides_make"),
  pattern = { "make" },
  callback = function()
    vim.opt_local.expandtab = false  -- Makefiles require real tabs
  end,
})

-- ----------------------------------------------------------------------------
-- Close certain utility windows with just <q>
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("close_with_q"),
  pattern = {
    "help", "lspinfo", "man", "notify",
    "qf", "startuptime", "checkhealth",
    "neotest-output", "neotest-output-panel",
  },
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<CR>",
      { buffer = ev.buf, silent = true, desc = "Close window" })
  end,
})

-- ----------------------------------------------------------------------------
-- Resize splits when the terminal window is resized
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimResized", {
  group    = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- ----------------------------------------------------------------------------
-- Auto-create parent directories when saving a new file
-- ----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
  group    = augroup("auto_mkdir"),
  callback = function(ev)
    if ev.match:match("^%w%w+://") then return end   -- skip remote buffers
    local dir = vim.fn.fnamemodify(ev.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})
