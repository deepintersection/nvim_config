-- =============================================================================
-- lua/core/autocmds.lua — Global autocommands
-- =============================================================================
-- Group all autocmds under namespaced augroups so they can be safely
-- re-sourced without duplication.
-- =============================================================================

local function augroup(name)
  return vim.api.nvim_create_augroup("config_" .. name, { clear = true })
end

-- -----------------------------------------------------------------------------
-- Highlight on yank
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 150 })
  end,
  desc = "Briefly highlight yanked text",
})

-- -----------------------------------------------------------------------------
-- Resize splits on terminal resize
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
  desc = "Auto-resize splits on terminal resize",
})

-- -----------------------------------------------------------------------------
-- Restore cursor position on file open
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Restore cursor to last position",
})

-- -----------------------------------------------------------------------------
-- Close certain buffers with q
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "help", "lspinfo", "man", "notify", "qf", "startuptime",
    "checkhealth", "neotest-output", "neotest-summary", "spectre_panel",
    "query",  -- treesitter query editor
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>",
      { buffer = ev.buf, silent = true, desc = "Close buffer" })
  end,
  desc = "Close auxiliary buffers with q",
})

-- -----------------------------------------------------------------------------
-- Filetype-specific indentation (explicit, not relying on detect)
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("ft_indent"),
  pattern = { "lua", "javascript", "typescript", "json", "yaml", "toml",
               "html", "css", "markdown", "vim" },
  callback = function()
    vim.opt_local.tabstop     = 2
    vim.opt_local.shiftwidth  = 2
    vim.opt_local.softtabstop = 2
  end,
  desc = "2-space indentation for common web/config filetypes",
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("ft_indent_c"),
  pattern = { "c", "cpp", "make" },
  callback = function()
    vim.opt_local.tabstop     = 4
    vim.opt_local.shiftwidth  = 4
    vim.opt_local.softtabstop = 4
    -- C/C++ files: use tabs for make, keep expandtab for C
    if vim.bo.filetype == "make" then
      vim.opt_local.expandtab = false
    end
  end,
  desc = "4-space indentation for C/C++, tabs for Makefile",
})

-- -----------------------------------------------------------------------------
-- Spell checking for prose filetypes
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("spell_prose"),
  pattern = { "markdown", "text", "gitcommit", "rst" },
  callback = function()
    vim.opt_local.spell    = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.wrap     = true
    vim.opt_local.linebreak = true
  end,
  desc = "Enable spell and wrap for prose",
})

-- -----------------------------------------------------------------------------
-- Auto-create directories on save
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_mkdir"),
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then return end -- remote URLs
    local file = vim.uv.fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
  desc = "Auto-create parent directories when saving",
})

-- -----------------------------------------------------------------------------
-- Strip trailing whitespace on save (opt-in via env var)
-- -----------------------------------------------------------------------------
if vim.env.NVIM_STRIP_WHITESPACE == "1" then
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("strip_whitespace"),
    callback = function()
      local pos = vim.api.nvim_win_get_cursor(0)
      vim.cmd([[%s/\s\+$//e]])
      vim.api.nvim_win_set_cursor(0, pos)
    end,
    desc = "Strip trailing whitespace on save",
  })
end

-- -----------------------------------------------------------------------------
-- Terminal: enter insert mode automatically
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
  group = augroup("terminal_auto_insert"),
  pattern = "term://*",
  callback = function()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
    vim.cmd("startinsert")
  end,
  desc = "Terminal: hide line numbers and auto-enter insert mode",
})

-- -----------------------------------------------------------------------------
-- LSP: disable semantic tokens for large files (SSH performance)
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup("lsp_performance"),
  callback = function(ev)
    local buf = ev.buf
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- Disable semantic tokens for files over 5000 lines
    if line_count > 5000 then
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client then
        client.server_capabilities.semanticTokensProvider = nil
      end
    end
  end,
  desc = "Disable LSP semantic tokens for large files",
})

-- -----------------------------------------------------------------------------
-- 0.12: Treesitter — handle get_parser() returning nil safely
-- -----------------------------------------------------------------------------
-- This is a global safety wrapper. Language-specific parsers check nil
-- in their own files (lua/plugins/treesitter.lua).





-- #Folding
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "lua",
    "rust",
    "python",
    "c",
    "cpp",
    "bash",
    "json",
    "yaml",
    "toml",
  },

  callback = function(ev)
    local ok = pcall(vim.treesitter.get_parser, ev.buf)

    if not ok then
      return
    end

    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt_local.foldenable = false
  end,
})
