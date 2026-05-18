-- =============================================================================
-- lsp/pyright.lua — Pyright language server configuration
-- =============================================================================
-- Auto-loaded by vim.lsp.enable("pyright") when a Python buffer is opened.
-- Server command MUST be set via NVIM_PYRIGHT_PATH in the launch script.
-- Python interpreter MUST be set via NVIM_PYTHON_PATH (no auto-detection).
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_PYRIGHT_PATH, "--stdio" },

  filetypes = { "python" },

  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "pyrightconfig.json",
    ".git",
  },

  settings = {
    python = {
      -- Explicit interpreter path — NEVER auto-detected.
      -- Set NVIM_PYTHON_PATH in the launch script.
      pythonPath = (vim.env.NVIM_PYTHON_PATH ~= "" and vim.env.NVIM_PYTHON_PATH or nil),

      analysis = {
        -- Do not search for additional venvs or interpreters.
        autoSearchPaths      = false,
        useLibraryCodeForTypes = true,

        -- "openFilesOnly" is faster than "workspace" for large monorepos.
        -- Switch to "workspace" for full project-wide type checking.
        diagnosticMode       = "openFilesOnly",

        -- "basic" | "standard" | "strict"
        typeCheckingMode     = "basic",

        -- Inlay hints (shown via vim.lsp.inlay_hint, toggled with <leader>uh)
        inlayHints = {
          variableTypes         = true,
          functionReturnTypes   = true,
          callArgumentNames     = true,
          pytestParameters      = true,
        },
      },
    },
  },

  -- Prevent pyright from trying to find a venv itself.
  -- With pythonPath set, this is redundant, but explicit is better.
  before_init = function(_, config)
    local s = config.settings
    if s and s.python then
      s.python.venvPath = nil
      s.python.venv     = nil
    end
  end,
}
