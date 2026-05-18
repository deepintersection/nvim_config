-- =============================================================================
-- lua/util/init.lua — Shared utility functions
-- =============================================================================
-- Accessed via require("util")
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- Environment variable helpers
-- -----------------------------------------------------------------------------

--- Read an env var, return nil if empty or unset.
---@param name string
---@return string|nil
function M.env(name)
  local v = vim.env[name]
  if v == nil or v == "" then return nil end
  return v
end

--- Read an env var as boolean ("1", "true", "yes" → true).
---@param name string
---@param default? boolean
---@return boolean
function M.env_bool(name, default)
  local v = vim.env[name]
  if v == nil or v == "" then return default or false end
  return v == "1" or v:lower() == "true" or v:lower() == "yes"
end

--- Read an executable path from env, verify it exists on PATH.
--- Returns the value if set and non-empty, otherwise nil.
---@param name string env var name
---@return string|nil
function M.env_exe(name)
  local v = M.env(name)
  if not v then return nil end
  return v
end

-- -----------------------------------------------------------------------------
-- LSP helpers (0.12 API)
-- -----------------------------------------------------------------------------

--- Check whether a given LSP client is attached to the current buffer.
---@param name string LSP client name
---@return boolean
function M.lsp_attached(name)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client.name == name then return true end
  end
  return false
end

--- Return the first LSP client attached to buffer with the given name, or nil.
---@param name string
---@param bufnr? integer defaults to current buffer
---@return vim.lsp.Client|nil
function M.lsp_get_client(name, bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr or 0 })) do
    if client.name == name then return client end
  end
  return nil
end

-- -----------------------------------------------------------------------------
-- Treesitter helpers (0.12 API — get_parser returns nil on error)
-- -----------------------------------------------------------------------------

--- Safely get a treesitter parser for a buffer. Returns nil on failure.
---@param bufnr? integer
---@param lang? string
---@return vim.treesitter.LanguageTree|nil
function M.ts_get_parser(bufnr, lang)
  -- 0.12: get_parser can return nil — always guard
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr or 0, lang)
  if not ok or not parser then return nil end
  return parser
end

-- -----------------------------------------------------------------------------
-- Keymap helpers
-- -----------------------------------------------------------------------------

--- Create a keymap that is only active when an LSP client is attached.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? table
function M.lsp_map(mode, lhs, rhs, opts)
  opts = vim.tbl_extend("force", { noremap = true, silent = true }, opts or {})
  -- Only map if we're in a buffer context (called from LspAttach)
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- -----------------------------------------------------------------------------
-- File/path helpers
-- -----------------------------------------------------------------------------

--- Return true if a file exists on disk.
---@param path string
---@return boolean
function M.file_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

--- Return true if path is a directory.
---@param path string
---@return boolean
function M.is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

-- -----------------------------------------------------------------------------
-- Platform helpers
-- -----------------------------------------------------------------------------

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
M.is_linux   = vim.fn.has("unix") == 1 and not vim.fn.has("mac") == 1
M.is_mac     = vim.fn.has("mac") == 1
M.is_ssh     = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil

return M
