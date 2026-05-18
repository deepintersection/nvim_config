
-- =============================================================================
-- lsp/yamlls.lua — yaml-language-server configuration
-- =============================================================================
-- Handles: YAML files (CI pipelines, k8s manifests, docker-compose, etc.)
-- Server command set via NVIM_YAMLLS_PATH in the launch script.
-- Install: npm i -g yaml-language-server
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_YAMLLS_PATH, "--stdio" },

  filetypes = { "yaml", "yaml.docker-compose", "yaml.github-actions" },

  root_markers = { ".git" },

  settings = {
    yaml = {
      schemaStore = {
        -- Enable schema store (fetches schemas from SchemaStore.org)
        enable = true,
        url    = "https://www.schemastore.org/api/json/catalog.json",
      },

      -- Common schema associations (without SchemaStore plugin)
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"]
          = ".github/workflows/*.{yml,yaml}",
        ["https://json.schemastore.org/github-action.json"]
          = ".github/actions/**/action.{yml,yaml}",
        ["https://json.schemastore.org/docker-compose.json"]
          = "docker-compose*.{yml,yaml}",
        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"]
          = "compose*.{yml,yaml}",
        ["https://json.schemastore.org/pre-commit-config.json"]
          = ".pre-commit-config.{yml,yaml}",
      },

      validate           = true,
      completion         = true,
      hover              = true,
      format             = { enable = false },  -- use conform.nvim (step 5)
      editor             = { tabSize = 2 },
      keyOrdering        = false,  -- don't enforce alphabetical key order
    },
    redhat = { telemetry = { enabled = false } },
  },
}
