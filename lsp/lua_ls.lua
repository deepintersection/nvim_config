-- =============================================================================
-- lsp/lua_ls.lua — Lua Language Server configuration
-- =============================================================================
-- Server command set via NVIM_LUA_LS_PATH in the launch script.
--
-- lazydev.nvim (configured in plugins/lsp.lua) dynamically injects
-- the Neovim API and plugin paths into lua_ls's workspace library.
-- This file provides only the base settings; lazydev handles the rest.
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = { vim.env.NVIM_LUA_LS_PATH },

  filetypes = { "lua" },

  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".stylua.toml",
    "stylua.toml",
    ".git",
  },

  settings = {
    Lua = {
      runtime = {
        -- Neovim embeds LuaJIT
        version = "LuaJIT",
      },

      workspace = {
        -- lazydev.nvim adds plugin paths dynamically — don't need them here.
        checkThirdParty = false,
        -- Still add VIMRUNTIME so non-lazydev buffers get basic vim.* types.
        library = {
          vim.env.VIMRUNTIME,
        },
      },

      completion = {
        callSnippet = "Replace",  -- "Disable" | "Both" | "Replace"
        keywordSnippet = "Replace",
      },

      hint = {
        enable       = true,
        setType      = true,
        paramName    = "All",   -- "All" | "Literal" | "Disable"
        paramType    = true,
        arrayIndex   = "Disable",
        await        = true,
      },

      diagnostics = {
        -- "vim" global already known via VIMRUNTIME; lazydev adds more.
        globals  = { "vim" },
        -- Disable noisy warnings that lazydev makes irrelevant
        disable  = { "missing-fields" },
        severity = {
          ["undefined-global"] = "Warning",  -- not Error; plugins add globals
        },
      },

      format = {
        -- Disable lua_ls formatter — we use stylua via conform.nvim (step 5)
        enable = false,
      },

      telemetry = { enable = false },
    },
  },
}
