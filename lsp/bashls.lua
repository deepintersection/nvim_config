-- =============================================================================
-- lsp/bashls.lua — bash-language-server configuration
-- =============================================================================
-- Handles: bash, sh, zsh scripts.
-- Server command set via NVIM_BASHLS_PATH in the launch script.
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_BASHLS_PATH, "start" },

  filetypes = { "sh", "bash", "zsh" },

  root_markers = { ".git", ".bashrc", ".bash_profile", ".zshrc" },

  settings = {
    bashIde = {
      globPattern            = "*@(.sh|.inc|.bash|.command)",
      enableSourceErrorDiagnostics = false,  -- too noisy for sourced files
      shellcheckPath         = "",  -- empty = use shellcheck from PATH if found
      shellcheckArguments    = "",
      explainshellEndpoint   = "",  -- don't call external service
      backgroundAnalysisMaxFiles = 500,
    },
  },
}
