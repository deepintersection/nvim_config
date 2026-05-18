-- =============================================================================
-- lsp/rust_analyzer.lua — rust-analyzer configuration
-- =============================================================================
-- Server command set via NVIM_RUST_ANALYZER_PATH in the launch script.
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_RUST_ANALYZER_PATH },

  filetypes = { "rust" },

  root_markers = { "Cargo.toml", "Cargo.lock", ".git" },

  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures          = true,
        loadOutDirsFromCheck = true,
        runBuildScripts      = true,
      },

      checkOnSave = {
        allFeatures = true,
        command     = "clippy",
        extraArgs   = { "--no-deps" },
      },

      procMacro = {
        enable  = true,
        -- Ignore known noisy proc macros that aren't user code
        ignored = {
          ["async-trait"]    = { "async_trait" },
          ["napi-derive"]    = { "napi" },
          ["async-recursion"] = { "async_recursion" },
        },
      },

      inlayHints = {
        bindingModeHints = { enable = false },
        closureStyle     = "impl_fn",
        lifetimeElisionHints = {
          enable         = "skip_trivial",
          useParameterNames = true,
        },
        parameterHints    = { enable = true },
        typeHints         = { enable = true },
        chainingHints     = { enable = true },
        closureReturnTypeHints = { enable = "with_block" },
      },

      diagnostics = {
        enable         = true,
        enableExperimental = false,
      },

      completion = {
        autoimport  = { enable = true },
        autoself    = { enable = true },
        postfix     = { enable = true },
      },

      -- Disable features that are slow on large workspaces or over SSH
      workspace = {
        symbol = { search = { limit = 128 } },
      },
    },
  },
}1~
