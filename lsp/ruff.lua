-- =============================================================================
-- lsp/ruff.lua — Ruff language server configuration
-- =============================================================================
-- Uses `ruff server` (built-in LSP mode, available since ruff ≥ 0.2.0).
-- This is NOT the deprecated `ruff-lsp` package.
--
-- Ruff handles: linting, import sorting, some formatting.
-- Pyright handles: type checking, completions.
-- Both run simultaneously on Python files.
--
-- Server command set via NVIM_RUFF_PATH in the launch script.
-- =============================================================================
 
---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_RUFF_PATH, "server" },
 
  filetypes = { "python" },
 
  root_markers = {
    "pyproject.toml",
    "ruff.toml",
    ".ruff.toml",
    "setup.cfg",
    ".git",
  },
 
  init_options = {
    settings = {
      -- Ruff configuration is usually in pyproject.toml or ruff.toml.
      -- These are fallback settings when no config file is found.
      lineLength         = 88,      -- Black default; override in pyproject.toml
      fixAll             = false,   -- don't auto-fix all on save (use conform.nvim)
      organizeImports    = true,    -- enable isort-compatible import sorting
      logLevel           = "warn",
    },
  },
 
  -- Ruff conflicts with pyright for some diagnostic codes.
  -- Tell pyright to defer to ruff for linting-style diagnostics.
  on_attach = function(client, _bufnr)
    -- Disable ruff's hover in favour of pyright's richer hover
    client.server_capabilities.hoverProvider = false
  end,
}
 

