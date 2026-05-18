
-- =============================================================================
-- lsp/jsonls.lua — vscode-json-language-server configuration
-- =============================================================================
-- Handles: JSON, JSONC files.
-- Server command set via NVIM_JSONLS_PATH in the launch script.
-- Install: npm i -g vscode-langservers-extracted
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_JSONLS_PATH, "--stdio" },

  filetypes = { "json", "jsonc" },

  root_markers = { ".git" },

  -- jsonls requires snippetSupport capability to work correctly.
  -- It uses snippet syntax in completion items to position the cursor.
  -- This is merged with global capabilities in plugins/lsp.lua.
  capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
        },
      },
    },
  },

  settings = {
    json = {
      -- Built-in schemas (no SchemaStore plugin needed for common formats)
      schemas = {
        {
          fileMatch = { "package.json" },
          url       = "https://json.schemastore.org/package.json",
        },
        {
          fileMatch = { "tsconfig*.json" },
          url       = "https://json.schemastore.org/tsconfig.json",
        },
        {
          fileMatch = { ".eslintrc", ".eslintrc.json" },
          url       = "https://json.schemastore.org/eslintrc.json",
        },
        {
          fileMatch = { "pyrightconfig.json" },
          url       = "https://raw.githubusercontent.com/microsoft/pyright/main/packages/pyright/schemas/pyrightconfig.schema.json",
        },
        {
          fileMatch = { ".prettierrc", ".prettierrc.json" },
          url       = "https://json.schemastore.org/prettierrc.json",
        },
        {
          fileMatch = { "*.github/workflows/*.json" },
          url       = "https://json.schemastore.org/github-workflow.json",
        },
      },
      validate = { enable = true },
      format   = { enable = false },  -- use conform.nvim (step 5)
    },
  },
}
