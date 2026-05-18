
-- =============================================================================
-- lsp/taplo.lua — taplo TOML language server configuration
-- =============================================================================
-- Handles: TOML files (Cargo.toml, pyproject.toml, etc.)
-- Server command set via NVIM_TAPLO_PATH in the launch script.
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_TAPLO_PATH, "lsp", "stdio" },

  filetypes = { "toml" },

  root_markers = { ".git", "Cargo.toml", "pyproject.toml" },

  settings = {
    taplo = {
      configFile = {
        enabled  = true,
        path     = ".taplo.toml",
      },
      schema = {
        enabled       = true,
        repositoryEnabled = true,
        repositoryUrl = "https://taplo.tamasfe.dev/schema_index.json",
        associations  = {
          -- Map specific TOML files to known schemas
          ["Cargo.toml"]       = "taplo://Cargo.toml",
          ["pyproject.toml"]   = "https://json.schemastore.org/pyproject.json",
        },
      },
      formatter = {
        -- Disable taplo formatter — we use conform.nvim (step 5)
        ignoreEmptyLines = false,
      },
    },
  },
}
